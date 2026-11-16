# AGENTS.md

This repository records and reproduces one legacy GPU inference setup. The verified deployment used NVIDIA Fermi GT 520M, PCI ID `10de:1050`, Compute Capability 2.1 (`sm_21`), NVIDIA 390.157, CUDA 8.0.61, x86-64 fnOS 1.2.1010 with kernel `6.18.18.c1186-trim`, and Darknet Tiny YOLOv2 COCO at 416×416. CPU baseline hardware was an Intel Core i3-2350M.

## Read in this order

1. [README.md](README.md) for the setup, manual recovery steps, compatibility and licenses.
2. [evidence/verification.md](evidence/verification.md) and [evidence/benchmark.json](evidence/benchmark.json) for status, provenance, metric definitions and measurements.
3. [The Agent Skill](skills/legacy-nvidia-cuda8-yolo/SKILL.md) for decision steps and focused troubleshooting.
4. [Dockerfile](Dockerfile) and [scripts/](scripts/) before executing a build or smoke test. [CONTRIBUTING.md](CONTRIBUTING.md) describes how to record a new result.

## Preserve the evidence boundary

- **VERIFIED** on the named NAS: patched 390.157 modules were built and temporarily loaded. The GPU was bound, enumerated and used for actual Tiny YOLOv2 inference. The NAS benchmark used an offline image assembled from prebuilt binaries and runtime libraries.
- The repository Dockerfile and scripts are reconstruction tools. Cite their own validation status from the evidence file. A compile, an `sm_21` inspection, or `nvidia-smi` alone cannot establish that a Docker workload ran on the GPU.
- Known failures include the Debian patched driver build on this kernel, missing `ipmi_msghandler`, missing `/dev/nvidiactl`, missing legacy NVIDIA user-space libraries, and image registry access. See the [troubleshooting reference](skills/legacy-nvidia-cuda8-yolo/references/troubleshooting.md).
- Keep single-image inference separate from video throughput and end-to-end latency. Other Fermi cards, kernels and streaming workloads need their own evidence.

## Run and validate

Start with read-only environment checks. Build in an isolated directory as a regular user. Review any proposed privileged module loading and device-node creation with the operator. Preserve existing driver bindings, boot entries, running containers and NAS services. Use disposable test containers, read-only input mounts, explicit device access and no network during inference. Keep credentials and private configuration out of commands, logs and contributions.

After edits, run `bash -n` for shell scripts, `git diff --check`, parse the JSON and recalculate its statistics, and validate the skill with `skills-ref validate skills/legacy-nvidia-cuda8-yolo`. If Docker is available, build the image and verify `sm_21`; run a CPU smoke test with the official weights. GPU and kernel-module validation requires the matching host. Report individual pass/fail/skip status in the PR.

Use [Issues and PRs](CONTRIBUTING.md) to share hardware details, pinned dependencies, commands, status and sanitized evidence. Preserve the original benchmark when submitting a new system.
