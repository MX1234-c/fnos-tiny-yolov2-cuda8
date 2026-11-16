# Contributing

Open a [GitHub Issue](https://github.com/MX1234-c/fnos-tiny-yolov2-cuda8/issues/new/choose) for a hardware observation, reproduction failure or upstream compatibility change. Use a pull request when there is a documentation, script or evidence change ready to review. Link the Issue when one exists.

1. Record hardware names and PCI IDs, OS/kernel, module and user-space driver versions, CUDA, container identity, source and weight hashes, plus the exact commands or script arguments relevant to your result.
2. Label each claim **VERIFIED**, **DOCUMENTED**, **UNTESTED** or **FAILED** using the definitions in [verification.md](evidence/verification.md). A failure contains its stage, sanitized error and any workaround. If raw logs are missing, state what was retained.
3. For benchmarking, use the same input, settings and weights for both modes. Include the metric definition, number of attempts, all raw elapsed times, failures or exclusions and median calculation. Record new configurations in a separate Markdown or JSON file in `evidence/` and link it from the verification index. Preserve the reference result.
4. Run applicable checks from [AGENTS.md](AGENTS.md). Submit a focused branch and PR. Report what could be tested on a development machine, and what used the target hardware.

Share readable text and small sanitized excerpts. Keep credentials, host addresses, identifying paths, binary drivers, image archives, outputs and model weights out of Git. Link third-party source and license information where applicable.
