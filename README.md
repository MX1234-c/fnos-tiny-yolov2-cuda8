# 飞牛 NAS 上的 CUDA 8 Tiny YOLOv2

在 fnOS 1.2.1010、内核 `6.18.18.c1186-trim`、GeForce GT 520M（PCI `10de:1050`，Fermi `sm_21`）上实测。驱动为 NVIDIA 390.157，模型为 Darknet Tiny YOLOv2 COCO。

## 实测

同一张官方样张、同一份权重、416×416 模型输入。每次启动一次性 Docker 容器，记录 Darknet 自带的推理计时，单位为秒。

- CUDA：0.282816、0.299216、0.525062，中位数 0.299216。
- CPU（i3-2350M）：2.666583、2.316063、2.518239，中位数 2.518239。
- 两组均识别出 person 91%，所有进程正常退出。中位数加速约 8.4 倍。
- 摄像头解码、端到端延迟、长期运行和骁龙 410 的基准尚未测试。

## 编译 CUDA 8 程序

在能访问 Docker Hub 和 NVIDIA 软件包源的 x86-64 机器上运行：

```sh
docker build --platform linux/amd64 -t tiny-yolov2-cuda8:sm21 -f Dockerfile .
docker save tiny-yolov2-cuda8:sm21 | gzip > tiny-yolov2-cuda8.tar.gz
```

镜像固定了 Darknet 源码提交，使用 CUDA 8.0.61，关闭 cuDNN 和 OpenCV，生成 `sm_21` 并在构建时检查二进制。将归档传到 NAS 后用 `gzip -dc tiny-yolov2-cuda8.tar.gz | sudo docker load` 导入。实测时飞牛镜像源返回 401，直连 Docker Hub 超时，因此在 NAS 上用已经编译好的程序和依赖构建了离线镜像。上面的保存和导入命令是供下次使用的简化传输方案。

## 构建旧版宿主机驱动

准备匹配运行内核的构建目录，核对 `Makefile`、`Module.symvers` 和 `include/config/auto.conf`。实测使用 GCC 12 和 binutils 2.40。以下命令在普通用户的独立工作目录执行。若将 Debian 工具包解包到临时目录，需要把其中的 `usr/bin` 和 `usr/lib/x86_64-linux-gnu` 加入搜索路径。

```sh
curl -fLO https://download.nvidia.com/XFree86/Linux-x86_64/390.157/NVIDIA-Linux-x86_64-390.157-no-compat32.run
sh NVIDIA-Linux-x86_64-390.157-no-compat32.run --check
sh NVIDIA-Linux-x86_64-390.157-no-compat32.run --extract-only --target raw390
git clone https://aur.archlinux.org/nvidia-390xx-utils.git patches390
git -C patches390 checkout 777edd19e80cffb6ca1fcce6fc2a6931f60cffc8
(
  set -eu
  cd raw390
  for patch_name in $(sed -n 's/^[[:space:]]*patch -Np1 -i \.\.\/\(.*\)$/\1/p' ../patches390/PKGBUILD | sed '/kernel-7.2.patch/,$d'); do
    patch -Np1 -i "../patches390/$patch_name"
  done
  kernel_build="/lib/modules/$(uname -r)/build"
  make -C kernel -j2 CC=gcc-12 HOSTCC=gcc-12 SYSSRC="$kernel_build" SYSOUT="$kernel_build" IGNORE_CC_MISMATCH=1 modules
)
modinfo -F version raw390/kernel/nvidia.ko
modinfo -F vermagic raw390/kernel/nvidia.ko
```

上面固定的是整理时核对的 Arch 补丁提交。NAS 实测下载了当时的 Arch 快照，未记录快照提交。Debian 的预打补丁源码在该飞牛内核上遇到 `get_user_pages_remote` 参数不匹配。更新 fnOS 内核后需重新编译和验证。

## 临时加载并验证

以下步骤需要管理员权限。在目标卡尚未绑定 NVIDIA 模块的情况下执行。确认工作目录内的源码和产物可信。

```sh
sudo modprobe ipmi_msghandler
sudo insmod "$PWD/raw390/kernel/nvidia.ko"
sudo insmod "$PWD/raw390/kernel/nvidia-uvm.ko"
sudo "$PWD/raw390/nvidia-modprobe" -c 0
sudo "$PWD/raw390/nvidia-modprobe" -u -c 0
test -e /dev/nvidiactl || sudo mknod -m 0666 /dev/nvidiactl c 195 255

mkdir -p driver-libs
cp raw390/libcuda.so.390.157 driver-libs/libcuda.so.1
cp raw390/libnvidia-ml.so.390.157 driver-libs/libnvidia-ml.so.1
cp raw390/libnvidia-fatbinaryloader.so.390.157 driver-libs/
cp raw390/libnvidia-ptxjitcompiler.so.390.157 driver-libs/
LD_LIBRARY_PATH="$PWD/driver-libs" raw390/nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
```

应看到 GT 520M、390.157 和约 964 MiB 显存。首次加载缺少 `ipmi_msghandler` 会报未知符号。缺少 `/dev/nvidiactl` 时管理工具无法通信。只提供 `libcuda.so.1` 时，实测 Darknet 报驱动版本不足。加入同版本 NVIDIA 辅助库后成功。

## 容器样张验证

```sh
curl -fL https://pjreddie.com/media/files/yolov2-tiny.weights -o yolov2-tiny.weights
sudo docker run --rm --network none \
  --device /dev/nvidia0 --device /dev/nvidiactl --device /dev/nvidia-uvm \
  -v "$PWD/driver-libs:/driver:ro" \
  -v "$PWD/yolov2-tiny.weights:/tmp/model.weights:ro" \
  -e LD_LIBRARY_PATH=/driver:/usr/local/cuda/lib64 \
  tiny-yolov2-cuda8:sm21 \
  detector test cfg/coco.data cfg/yolov2-tiny.cfg /tmp/model.weights data/person.jpg -thresh 0.25
```

上述命令对应本仓库的 Dockerfile。NAS 当时的离线镜像使用同一份 Darknet 二进制，命令入口是显式的 `/opt/darknet/darknet-gpu`。测试只用了临时驱动加载和一次性容器。需要长期运行时，将工作目录保存在持久卷，并在每次启动后按本节重新验证设备和样张。现有部署没有配置开机自动加载。
