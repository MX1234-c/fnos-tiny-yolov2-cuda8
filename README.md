# 飞牛 NAS 上的 CUDA 8 Tiny YOLOv2

Run Darknet Tiny YOLOv2 in Docker on a legacy NVIDIA Fermi GPU. This repository records a verified GT 520M setup and provides a reproducible starting point for Linux kernel driver and CUDA 8 troubleshooting on fnOS.

本项目在 fnOS 上用 NVIDIA 390.157 驱动和 CUDA 8.0.61 跑通了 GT 520M 的单图推理。适用的检索词包括飞牛 NAS、旧 NVIDIA 显卡、Linux 6.18 内核、Fermi、Compute Capability 2.1、sm_21、GT 520M、Darknet 和 Docker。

## 已验证范围

- 系统为 x86-64 fnOS 1.2.1010，内核为 `6.18.18.c1186-trim`。
- NVIDIA GeForce GT 520M，PCI ID `10de:1050`，Fermi Compute Capability 2.1（`sm_21`）。
- NVIDIA 390.157、CUDA 8.0.61、Darknet Tiny YOLOv2 COCO 与 416×416 输入。
- NAS 实测使用组装的**离线镜像**。仓库的 **Dockerfile 和脚本**是重新构建的入口，验证状态见 [evidence/verification.md](evidence/verification.md)。旧离线镜像和新版脚本需要的程序路径不同，即使镜像标签相同也应重新构建。

## 快速开始

1. 在目标机执行 `scripts/check_environment.sh`。缺少驱动、设备节点或 Docker 权限时，依据报告处理。
2. 在匹配内核的主机上，用普通用户执行 `scripts/build_driver.sh WORK_DIR`。按下文的手动加载说明检查构建产物、确认系统状态并临时加载模块。该脚本只负责构建。可以用 KERNEL_BUILD_DIR、CC（默认 gcc-12）和 JOBS 指定构建参数。成功时会报告独立构建目录，后续手动命令从该目录运行。
3. 在联网的 x86-64 Docker 环境构建仓库镜像，必要时导入 NAS。准备从 390.157 提取的 `driver-libs/`。
4. 从上游取得权重并核对 SHA256。运行 CUDA 探针，再实跑单张检测。按需重跑基准。

```sh
curl -fL https://pjreddie.com/media/files/yolov2-tiny.weights -o yolov2-tiny.weights
printf '%s\n' '16f4e870f1aed83f0089cb69bfda6b53cb7b2a4a01721be56eaf5c899dfac45f  yolov2-tiny.weights' | sha256sum -c -
scripts/verify_cuda.sh
scripts/run_inference.sh gpu yolov2-tiny.weights
scripts/run_inference.sh cpu yolov2-tiny.weights
scripts/benchmark.sh yolov2-tiny.weights
```

脚本默认使用 `tiny-yolov2-cuda8:sm21` 和当前目录的 `driver-libs/`，可用 `YOLO_IMAGE` 和 `DRIVER_LIBS` 指定。推理和基准命令可传入自己的图片路径，省略时使用 Darknet 样张。用具备 Docker 权限的账号运行；Docker 权限应由 NAS 管理员在现有权限体系内安排。下文也提供独立的手动命令。

## 实测

同一张官方样张、同一份权重、416×416 模型输入。每次启动一次性 Docker 容器，记录 Darknet 自带的推理计时，单位为秒。

- CUDA：0.282816、0.299216、0.525062，中位数 0.299216。
- CPU（i3-2350M）：2.666583、2.316063、2.518239，中位数 2.518239。
- 两组均识别出 person 91%，所有进程正常退出。中位数加速约 8.4 倍。
- 摄像头解码、端到端延迟、长期运行和骁龙 410 的基准尚未测试。

原始耗时与测试定义见 [benchmark.json](evidence/benchmark.json)。

## 编译 CUDA 8 程序

在能访问 Docker Hub 和 NVIDIA 软件包源的 x86-64 机器上运行：

```sh
docker build --platform linux/amd64 -t tiny-yolov2-cuda8:sm21 -f Dockerfile .
docker save tiny-yolov2-cuda8:sm21 | gzip > tiny-yolov2-cuda8.tar.gz
```

镜像固定了 Darknet 源码提交，使用 CUDA 8.0.61，关闭 cuDNN 和 OpenCV，生成 `sm_21` 并在构建时检查二进制。将归档传到 NAS 后用 `gzip -dc tiny-yolov2-cuda8.tar.gz | sudo docker load` 导入。实测时飞牛镜像源返回 401，直连 Docker Hub 超时，因此在 NAS 上用已经编译好的程序和依赖构建了离线镜像。上面的保存和导入命令是供下次使用的简化传输方案。

## 构建旧版宿主机驱动

准备匹配运行内核的构建目录，核对 `Makefile`、`Module.symvers` 和 `include/config/auto.conf`。实测使用 GCC 12 和 binutils 2.40。以下命令在普通用户的独立工作目录执行。若校验失败，停止并检查下载来源。若将 Debian 工具包解包到临时目录，需要把其中的 `usr/bin` 和 `usr/lib/x86_64-linux-gnu` 加入搜索路径。

```sh
curl -fLO https://download.nvidia.com/XFree86/Linux-x86_64/390.157/NVIDIA-Linux-x86_64-390.157-no-compat32.run
printf '%s\n' '162317a49aa5a521eb888ec12119bfe5a45cec4e8653efc575a2d04fb05bf581  NVIDIA-Linux-x86_64-390.157-no-compat32.run' | sha256sum -c -
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

上面固定的是整理时核对的 Arch 补丁提交。整理期间在 Linux 环境独立应用了该序列的 18 个补丁。NAS 实测下载了当时的 Arch 快照，未记录快照提交。Debian 的预打补丁源码在该飞牛内核上遇到 `get_user_pages_remote` 参数不匹配。更新 fnOS 内核后需重新编译和验证。

## 临时加载并验证

以下步骤需要管理员权限。在目标卡尚未绑定 NVIDIA 模块的情况下执行。确认工作目录内的源码和产物可信。加载模块会改变正在运行的内核状态。若显卡已有绑定、同名模块已加载或 NAS 正在使用该设备，先查明占用及影响。下方 0666 是历史实验使用的临时权限，生产环境应按本机设备访问策略设置。

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

## 已知限制

- 驱动临时加载，重启后需要重新验证和加载。fnOS 更新内核后，按新内核重新检查依赖、构建并验证；仅有 `vermagic` 匹配不能证明加载安全。
- 老旧驱动与 Ubuntu 16.04 用户态处于历史版本。把重建和验证放在隔离环境，应用上线前另行评估维护与安全要求。
- Dockerfile 固定基础镜像摘要、Darknet 提交、CUDA 包版本及每个 CUDA 包的 SHA256。Ubuntu 构建依赖来自 apt 仓库，镜像可用性与字节级可重建性仍取决于外部软件源。
- 当前数据只覆盖指定 GT 520M 和单张推理，其它 GPU、直播视频和长期稳定性需另行测试。Docker 内的 CUDA 探针成功也只证明设备可用，完成模型推理才验证该工作负载。

## Agent 和贡献

Agent 可从 [AGENTS.md](AGENTS.md) 开始阅读。支持 [Agent Skills 开放规范](https://agentskills.io/specification) 的客户端可按自己的项目级 Skill 发现或导入规则加载 [legacy-nvidia-cuda8-yolo](skills/legacy-nvidia-cuda8-yolo/SKILL.md)。单独安装 Skill 目录时，其 reference 会指向完整仓库；仓库也可以通过 GitHub 搜索或直接链接手动发现。

请用 Issue 和 PR 记录新硬件、失败试验、性能数据或复现修复。见 [贡献指南](CONTRIBUTING.md)。

建议的 GitHub Description 为 “CUDA 8 Tiny YOLOv2 on fnOS Docker with NVIDIA Fermi GT 520M and driver 390.157. Reproducible scripts and benchmark evidence.”
建议 Topics 为 `fnos`、`cuda8`、`nvidia-fermi`、`gt-520m`、`tiny-yolov2`、`darknet`、`docker`、`legacy-gpu`、`reproducibility`、`agent-skills`。

## 许可证和上游材料

本项目目前没有根 LICENSE。建议维护者确认贡献权属后，为自有脚本和文档选用 MIT 并添加 LICENSE，明确不覆盖第三方材料。公开可读的仓库状态本身未授予开源许可。

- 固定提交的 Darknet 仓库将其代码声明为 public domain。模型权重和样张的授权范围应分别核对。仓库仅记录上游权重下载地址和校验值。[Darknet 源码许可](https://github.com/pjreddie/darknet/blob/f6afaabcdf85f77e7aff2ec55c020c0e297c77f9/LICENSE)
- NVIDIA CUDA 8 工具链、用户态库及 390.157 驱动适用其各自条款。镜像归档含第三方二进制，转发或发布镜像前应核对相应条款。仓库只提供源码级构建与复现说明。[CUDA 8 EULA](https://docs.nvidia.com/cuda/archive/8.0/eula/index.html) · [NVIDIA 390.157 驱动文档](https://download.nvidia.com/XFree86/Linux-x86_64/390.157/README/)
- Arch 补丁从固定提交获取。贡献者若要在本仓库分发补丁或其他上游资产，应先检查各文件的授权与署名条件。[Arch 补丁来源](https://aur.archlinux.org/packages/nvidia-390xx-dkms)
