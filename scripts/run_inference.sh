#!/usr/bin/env bash
set -euo pipefail
usage() { printf 'Usage: %s gpu|cpu WEIGHTS [IMAGE]\n' "$0"; }
if [[ ${1:-} == --help ]]; then usage; exit 0; fi
if [[ $# -lt 2 || $# -gt 3 || ! $1 =~ ^(gpu|cpu)$ ]]; then usage >&2; exit 2; fi
source "$(dirname -- "${BASH_SOURCE[0]}")/container_common.sh"

weights=$(realpath -e -- "$2") || die 'COCO weights file was not found.'
[[ -f $weights && $weights != *,* ]] || die 'WEIGHTS must be a regular file with no comma in its path.'
expected=16f4e870f1aed83f0089cb69bfda6b53cb7b2a4a01721be56eaf5c899dfac45f
actual=$(sha256sum < "$weights") || die 'Could not hash the weights file.'
[[ ${actual%% *} == "$expected" ]] || die 'COCO weights SHA256 mismatch.'

prepare_container
program=/opt/darknet/darknet-cpu
if [[ $1 == gpu ]]; then
    prepare_gpu
    program=/opt/darknet/darknet
fi
options+=(--mount "type=bind,src=$weights,dst=/tmp/model.weights,readonly")
input=data/person.jpg
if [[ $# == 3 ]]; then
    asset=$(realpath -e -- "$3") || die 'Input image was not found.'
    [[ -f $asset && $asset != *,* ]] || die 'IMAGE must be a regular file with no comma in its path.'
    input=/tmp/input-image
    options+=(--mount "type=bind,src=$asset,dst=$input,readonly")
fi

# This Darknet revision also exits zero on invalid images or missing config files.
status=0
output=$(docker run "${options[@]}" --entrypoint "$program" "$image" \
    detector test cfg/coco.data cfg/yolov2-tiny.cfg /tmp/model.weights "$input" -thresh 0.25 2>&1) || status=$?
printf '%s\n' "$output"
if (( status != 0 )); then exit "$status"; fi
grep -Eq ': Predicted in [0-9]+([.][0-9]+)? seconds[.]$' <<< "$output" \
    || die 'Darknet returned without completing inference.'
