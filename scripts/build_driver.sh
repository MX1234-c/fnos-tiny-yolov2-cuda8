#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 WORK_DIR"
    echo "Build NVIDIA 390.157 for the running Linux x86_64 kernel as a regular user."
    echo "Optional environment: KERNEL_BUILD_DIR, CC (GCC 12, default gcc-12), JOBS (default 2)."
    echo "Only writes to a new subdirectory of WORK_DIR. Loading the result is a separate manual operation."
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

if [[ ${1:-} == --help && $# -eq 1 ]]; then
    usage
    exit 0
fi
if (( $# != 1 )) || [[ $1 == -* || -z $1 ]]; then
    usage >&2
    exit 2
fi

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || fail "Linux x86_64 is required."
(( EUID != 0 )) || fail "Run this build as a regular user."

kernel=$(uname -r)
headers=${KERNEL_BUILD_DIR:-/lib/modules/$kernel/build}
compiler=${CC:-gcc-12}
jobs=${JOBS:-2}
[[ $jobs =~ ^[1-9][0-9]*$ ]] || fail "JOBS must be a positive integer."

for tool in "$compiler" ld make git patch curl sha256sum; do
    command -v "$tool" >/dev/null || fail "Required tool missing: $tool"
done
modinfo=$(command -v modinfo || true)
if [[ -z $modinfo && -x /sbin/modinfo ]]; then
    modinfo=/sbin/modinfo
fi
[[ -n $modinfo ]] || fail "modinfo (kmod) is required to verify the build."
[[ $("$compiler" -dumpversion) == 12* ]] || fail "Use GCC 12 for the documented build."
[[ -d $headers ]] || fail "Kernel build directory not found: $headers"
headers=$(cd -- "$headers" && pwd -P)
for file in Makefile Module.symvers include/config/auto.conf; do
    [[ -r $headers/$file ]] || fail "Missing $headers/$file. Supply prepared headers for $kernel."
done
if [[ $kernel != 6.18.18.c1186-trim ]]; then
    printf 'NOTE: %s is outside the verified fnOS kernel configuration.\n' "$kernel"
fi

driver_version=390.157
installer=NVIDIA-Linux-x86_64-${driver_version}-no-compat32.run
installer_sha256=162317a49aa5a521eb888ec12119bfe5a45cec4e8653efc575a2d04fb05bf581
patch_commit=777edd19e80cffb6ca1fcce6fc2a6931f60cffc8
patches=(
    kernel-4.16+-memory-encryption.patch
    kernel-6.2.patch
    kernel-6.3.patch
    kernel-6.4.patch
    kernel-6.5.patch
    kernel-6.6.patch
    kernel-6.8.patch
    gcc-14.patch
    kernel-6.10.patch
    kernel-6.12.patch
    kernel-6.13.patch
    kernel-6.14.patch
    gcc-15.patch
    kernel-6.15.patch
    kernel-6.17.patch
    kernel-6.19.patch
    kernel-6.18-nv_workqueue_flush.patch
    kernel-7.0.patch
)

mkdir -p -- "$1"
work_dir=$(cd -- "$1" && pwd -P)
build_dir=$(mktemp -d "$work_dir/nvidia-390.157.XXXXXX")
printf 'Build directory: %s\n' "$build_dir"
cd -- "$build_dir"
curl --proto '=https' --proto-redir '=https' --fail --location --silent --show-error \
    --connect-timeout 15 --max-time 600 --retry 2 \
    "https://download.nvidia.com/XFree86/Linux-x86_64/$driver_version/$installer" -o "$installer"
printf '%s  %s\n' "$installer_sha256" "$installer" | sha256sum -c -
sh "$installer" --check
sh "$installer" --extract-only --target raw390
git clone --no-checkout https://aur.archlinux.org/nvidia-390xx-utils.git patches390
git -C patches390 checkout --detach "$patch_commit"

cd raw390
for patch_name in "${patches[@]}"; do
    patch --batch --forward -p1 -i "$build_dir/patches390/$patch_name"
done
make -C kernel -j "$jobs" CC="$compiler" HOSTCC="$compiler" \
    SYSSRC="$headers" SYSOUT="$headers" IGNORE_CC_MISMATCH=1 modules

for module in nvidia nvidia-uvm; do
    ko=kernel/$module.ko
    [[ -s $ko ]] || fail "Expected module missing: $ko"
    vermagic=$("$modinfo" -F vermagic "$ko")
    [[ ${vermagic%% *} == "$kernel" ]] || fail "$ko vermagic does not match $kernel: $vermagic"
done
version=$("$modinfo" -F version kernel/nvidia.ko)
[[ $version == "$driver_version" ]] || fail "nvidia.ko reports unexpected version: $version"
printf 'OK: built and checked NVIDIA %s modules for %s in %s/raw390/kernel\n' \
    "$driver_version" "$kernel" "$build_dir"
echo "Modules are not loaded. Review the manual loading procedure before using administrator privileges."
