#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
usage() { printf 'Usage: %s WEIGHTS [IMAGE (empty for sample)] [RUNS (default 3)]\n' "$0"; }
if [[ ${1:-} == --help ]]; then usage; exit 0; fi
runs=${3:-3}
if [[ $# -lt 1 || $# -gt 3 || ! $runs =~ ^[1-9][0-9]{0,3}$ ]]; then
    usage >&2
    exit 2
fi

runner="$(dirname -- "${BASH_SOURCE[0]}")/run_inference.sh"
args=("$1")
if [[ -n ${2:-} ]]; then args+=("$2"); fi
temp=$(mktemp -d)
trap 'rm -f -- "$temp/gpu" "$temp/cpu"; rmdir -- "$temp"' EXIT
printf 'mode,run,inference_seconds\n'
for ((i=1; i<=runs; i++)); do
    for mode in gpu cpu; do
        if ! result=$(bash "$runner" "$mode" "${args[@]}" 2>&1); then
            printf '%s run %s failed:\n%s\n' "$mode" "$i" "$result" >&2
            exit 1
        fi
        seconds=$(awk '/Predicted in [0-9]+([.][0-9]+)? seconds[.]/ {
            for (i=1; i<NF; i++) if ($i=="in" && $(i-1)=="Predicted") print $(i+1)
        }' <<< "$result")
        if [[ ! $seconds =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            printf 'Expected one Darknet timing in %s run %s:\n%s\n' "$mode" "$i" "$result" >&2
            exit 1
        fi
        printf '%s,%s,%s\n' "$mode" "$i" "$seconds"
        printf '%s\n' "$seconds" >> "$temp/$mode"
    done
done
median() {
    sort -n "$1" | awk '{v[NR]=$1} END {
        if (NR % 2) printf "%.9f", v[(NR+1)/2]
        else printf "%.9f", (v[NR/2]+v[NR/2+1])/2
    }'
}
gpu=$(median "$temp/gpu")
cpu=$(median "$temp/cpu")
awk -v gpu="$gpu" -v cpu="$cpu" 'BEGIN {
    if (gpu <= 0 || cpu <= 0) {print "Invalid median duration"; exit 1}
    printf "Median GPU %.6f s, CPU %.6f s, speedup %.2fx\n", gpu, cpu, cpu/gpu
}' >&2
