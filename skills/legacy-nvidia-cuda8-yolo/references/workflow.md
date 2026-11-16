# Select a workflow

Use the full [project checkout](https://github.com/MX1234-c/fnos-tiny-yolov2-cuda8) alongside this skill for the scripts, build definitions and evidence. In the checkout, start with `README.md`, `AGENTS.md` and `evidence/verification.md`. A client that imports only the skill directory can fetch those documents before executing any commands.

- For initial triage, use `scripts/check_environment.sh` and capture the PCI ID and bound driver. Kernel candidates printed by `lspci -nnk` are distinct from the active binding.
- For a missing legacy driver, see the manual build section or use `scripts/build_driver.sh WORK_DIR` with headers for the running kernel. Module insertion is a separate, explicit administrator action.
- For a rebuilt project image, run `scripts/verify_cuda.sh` followed by `scripts/run_inference.sh gpu WEIGHTS`. The historical offline benchmark used an explicitly named `darknet-gpu` binary and a different image layout. Keep these entry points separate.
- For performance, run `scripts/benchmark.sh WEIGHTS [IMAGE] [RUNS]` and record the raw durations along with the actual GPU, CPU, kernel, driver, image and weight identity.
- For an unmatched system, document the changed hardware or software before choosing a build. In particular, the CUDA 8 toolchain and the 390.157 driver each have their own compatibility requirements.
