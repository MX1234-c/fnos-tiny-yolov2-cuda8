# Evidence status

- **VERIFIED** — On fnOS 1.2.1010 with kernel 6.18.18.c1186-trim, NVIDIA 390.157 was compiled from NVIDIA source plus an Arch snapshot, loaded temporarily, and bound to GT 520M (10de:1050). NVIDIA's utility enumerated the device. CUDA 8 Tiny YOLOv2 then detected a person in the upstream sample, both natively and with explicit Docker device and driver-library mounts. Three GPU and three CPU Docker timings are in [benchmark.json](benchmark.json).
- **VERIFIED** — The NAS benchmark used an image assembled offline from previously built executables and dependencies. The original GPU Dockerfile was compiled on another PC and its sm_21 objects were inspected there.
- **FAILED** — NAS mirror returned HTTP 401 and direct Docker Hub timed out. Debian's packaged 390.157 source hit a get_user_pages_remote compatibility error on this kernel. Loading the standalone module before ipmi_msghandler produced unresolved symbols. The initial device setup lacked /dev/nvidiactl. With only libcuda.so.1 staged, Darknet reported an insufficient driver version. Adding the matching proprietary helper libraries resolved it.
- **DOCUMENTED** — Pinned Arch commit and repository build/export/import workflow for the updated image. The exact Arch snapshot commit from the historical NAS run was not recorded.
- **UNTESTED** — New scripts on GT 520M, new image's CUDA probe on physical hardware, live streams, sustained operation, restart recovery, and other GPU or kernel combinations.

The historical measurements were transcribed into README.md at commit 8ede3ce. Original terminal logs are unavailable as repository artifacts. This record contains the measurements and observed outcomes, without reconstructed logs.

## Repository upgrade checks

- **VERIFIED** — On a separate Linux amd64 Docker engine, the revised Dockerfile built successfully, checked all ten CUDA package hashes, and emitted sm_21 objects for Darknet and the CUDA probe. The rebuilt CPU binary detected the upstream sample person at 91%. The probe returned nonzero without a GPU attached.
- **VERIFIED** — All shell files parsed with Bash. Fixtures exercised benchmark timing extraction, even-count medians, missing timing, command failure propagation, argument rejection, custom image mounts and invalid weight checks. The official Agent Skills validator passed.
- **VERIFIED** — NVIDIA's 390.157 archive was independently downloaded and checked, and all 18 patches at the pinned Arch commit applied to the unpacked source in Linux. Some hunks applied with offsets or fuzz. This checks patch application only. Kernel-module compilation, loading and GPU inference with the revised workflow remain untested on fnOS.
