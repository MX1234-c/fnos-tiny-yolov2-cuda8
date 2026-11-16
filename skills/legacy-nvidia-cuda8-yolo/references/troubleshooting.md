# Troubleshoot by layer

- **Build fails at `get_user_pages_remote`**. The Debian prepatched source hit this on the verified fnOS kernel. The successful run used the NVIDIA 390.157 installer extracted without installation and the Arch patch sequence. Check headers, generated configuration and `Module.symvers`.
- **`insmod` reports unknown IPMI symbols**. Check dependencies and the host kernel log. On the verified host, loading `ipmi_msghandler` first resolved the error.
- **`nvidia-smi` cannot communicate**. Verify the PCI binding and character nodes. The historical test needed `/dev/nvidia0`, `/dev/nvidia-uvm` and `/dev/nvidiactl`; the control node was missing after initial insertion.
- **CUDA reports an insufficient driver**. Verify that the kernel module and mounted `libcuda.so.1`, `libnvidia-fatbinaryloader.so.390.157` and `libnvidia-ptxjitcompiler.so.390.157` all belong to 390.157. Check that the container library search path includes the mounted directory. NVML is used separately for `nvidia-smi`.
- **NAS registry returns 401 or times out**. Build on a connected Linux/amd64 Docker builder and load the result locally on the NAS. The historical offline runtime image was assembled from copied binaries and dependencies.
- **GPU enumeration succeeds but inference fails**. Record the probe and the failed GPU run distinctly. Check `sm_21` code generation, accessible device mounts and selected binary. A successful CPU retry provides a CPU result only.
