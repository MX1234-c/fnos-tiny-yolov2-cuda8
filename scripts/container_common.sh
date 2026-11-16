#!/usr/bin/env bash
# Shared by run_inference.sh and verify_cuda.sh.
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

prepare_container() {
    command -v docker >/dev/null || die 'Docker CLI is required.'
    image=${YOLO_IMAGE:-tiny-yolov2-cuda8:sm21}
    docker image inspect "$image" >/dev/null || die "Build or load image $image and verify Docker access."
    options=(--rm --network none --workdir /opt/darknet --ulimit core=0)
}

prepare_gpu() {
    local libs version device library
    libs=$(realpath -e -- "${DRIVER_LIBS:-./driver-libs}") || die 'Set DRIVER_LIBS to the directory of matching NVIDIA libraries.'
    version=$(cat /sys/module/nvidia/version 2>/dev/null) || die 'The host NVIDIA module is not loaded.'
    [[ $version == 390.157 ]] || die "Expected host NVIDIA 390.157, found $version."
    for device in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm; do
        [[ -c $device ]] || die "Missing device $device. See the manual driver setup."
        options+=(--device "$device")
    done
    for library in libcuda.so.1 libnvidia-fatbinaryloader.so.390.157 libnvidia-ptxjitcompiler.so.390.157; do
        [[ -f $libs/$library ]] || die "Missing $library in DRIVER_LIBS."
    done
    [[ $libs != *,* ]] || die 'DRIVER_LIBS path cannot contain a comma.'
    options+=(--mount "type=bind,src=$libs,dst=/driver,readonly"
        --env LD_LIBRARY_PATH=/driver:/usr/local/cuda/lib64)
}
