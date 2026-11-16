#!/usr/bin/env bash
set -u

usage() {
    echo "Usage: $0"
    echo "Read-only check for the verified GT 520M runtime and optional driver build tools."
}

if [[ ${1:-} == --help && $# -eq 1 ]]; then
    usage
    exit 0
fi
if (( $# != 0 )); then
    usage >&2
    exit 2
fi

if [[ $(uname -s) != Linux ]]; then
    echo "FAIL: run this check on the Linux GPU host." >&2
    exit 1
fi

status=0
kernel=$(uname -r)
architecture=$(uname -m)
printf 'Host kernel: %s (%s)\n' "$kernel" "$architecture"
if [[ $architecture != x86_64 ]]; then
    echo "FAIL: the documented driver and image require Linux x86_64."
    status=1
fi
if [[ $kernel != 6.18.18.c1186-trim ]]; then
    echo "NOTE: this kernel is outside the verified fnOS configuration."
fi

found=0
for device in /sys/bus/pci/devices/*; do
    [[ -r $device/vendor && -r $device/device ]] || continue
    [[ $(<"$device/vendor") == 0x10de && $(<"$device/device") == 0x1050 ]] || continue
    found=1
    binding=$(readlink "$device/driver") || binding=unbound
    printf 'PCI %s: GeForce GT 520M (10de:1050), kernel driver: %s\n' "${device##*/}" "${binding##*/}"
    if [[ ${binding##*/} != nvidia ]]; then
        echo "FAIL: GT 520M is not bound to the NVIDIA driver."
        status=1
    fi
done
if (( found == 0 )); then
    echo "FAIL: GT 520M PCI ID 10de:1050 was not found."
    status=1
fi

if [[ -r /sys/module/nvidia/version && $(</sys/module/nvidia/version) == 390.157 ]]; then
    echo "OK: NVIDIA module 390.157 is loaded."
else
    version=unavailable
    if [[ -r /sys/module/nvidia/version ]]; then
        version=$(</sys/module/nvidia/version)
    fi
    printf 'FAIL: expected loaded NVIDIA module 390.157, found %s.\n' "$version"
    status=1
fi

for node in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm; do
    if [[ -c $node ]]; then
        printf 'OK: %s is a character device.\n' "$node"
    else
        printf 'FAIL: missing character device %s.\n' "$node"
        status=1
    fi
done

if command -v docker >/dev/null && server=$(docker info --format '{{.ServerVersion}}'); then
    printf 'OK: configured Docker daemon is reachable (server %s).\n' "$server"
    echo "Check that the configured Docker daemon is on this GPU host."
else
    echo "FAIL: Docker is missing or the configured daemon is unreachable."
    status=1
fi

headers=${KERNEL_BUILD_DIR:-/lib/modules/$kernel/build}
for file in Makefile Module.symvers include/config/auto.conf; do
    if [[ ! -r $headers/$file ]]; then
        printf 'BUILD NOTE: missing or unreadable %s/%s\n' "$headers" "$file"
    fi
done
for tool in "${CC:-gcc-12}" ld make git patch curl sha256sum; do
    if ! command -v "$tool" >/dev/null; then
        printf 'BUILD NOTE: missing %s\n' "$tool"
    fi
done
if ! command -v modinfo >/dev/null && [[ ! -x /sbin/modinfo ]]; then
    echo "BUILD NOTE: missing modinfo (kmod)."
fi
if (( status == 0 )); then
    echo "OK: host prerequisites found. Run verify_cuda.sh for a CUDA kernel test."
fi
exit "$status"
