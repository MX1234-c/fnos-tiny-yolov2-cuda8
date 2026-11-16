#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    printf 'Usage: %s (optional environment: YOLO_IMAGE, DRIVER_LIBS)\n' "$0"
    exit 0
fi
if [[ $# != 0 ]]; then printf 'Unexpected argument. See --help.\n' >&2; exit 2; fi
source "$(dirname -- "${BASH_SOURCE[0]}")/container_common.sh"
prepare_container
prepare_gpu
exec docker run "${options[@]}" --entrypoint /opt/darknet/cuda_probe "$image"
