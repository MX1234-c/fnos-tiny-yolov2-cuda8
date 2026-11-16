---
name: legacy-nvidia-cuda8-yolo
description: >-
  Diagnose and reproduce Tiny YOLOv2 inference with Darknet and Docker on a
  legacy NVIDIA GPU. Use for NVIDIA Fermi, CUDA 8, Compute Capability 2.1
  (sm_21), GT 520M, fnOS, NVIDIA 390.157, or legacy GPU driver and container
  compatibility issues. Separate a detected card from a proven GPU inference run.
compatibility: Bash on x86-64 Linux and Docker for the documented workflow. Driver construction requires matching kernel headers and GCC 12. Hardware verification requires the target GPU and a loaded compatible driver.
---

# Legacy NVIDIA CUDA 8 YOLO

1. Identify the PCI device and bound driver, kernel release and Docker access. Compare the results with the verified GT 520M (`10de:1050`) and fnOS kernel. Treat any deviation as a new configuration and record it separately.
2. Read [workflow.md](references/workflow.md) for the checkout and corresponding build, host and container entry points. Prefer the documented offline path when the target NAS cannot pull the base image.
3. Check for a matching 390.157 kernel module and user-space libraries before attempting CUDA. Build separately from loading. Review privileged actions with the operator and preserve any existing driver or service.
4. Verify in layers. Record device enumeration and Compute Capability 2.1, then run the GPU binary with the device nodes mounted and retain the successful inference output. Compilation checks and CPU-only runs have narrower verification scope.
5. Use [troubleshooting.md](references/troubleshooting.md) when a compile, driver probe or GPU test fails. Keep the exact error and the smallest successful change.
6. Benchmark both modes on the same pixels, weights and settings. Record every valid run, the median and what the timer measures. Use VERIFIED, DOCUMENTED, UNTESTED and FAILED for the scope each piece of evidence supports.
