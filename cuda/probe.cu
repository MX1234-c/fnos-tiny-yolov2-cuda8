#include <cuda_runtime.h>
#include <stdio.h>

__global__ void write_value(int *output)
{
    *output = 42;
}

static bool check(cudaError_t result, const char *operation)
{
    if (result == cudaSuccess) return true;
    fprintf(stderr, "%s: %s\n", operation, cudaGetErrorString(result));
    return false;
}

int main()
{
    cudaDeviceProp gpu;
    if (!check(cudaGetDeviceProperties(&gpu, 0), "Probe device 0")) return 1;
    printf("GPU: %s, compute capability: %d.%d\n", gpu.name, gpu.major, gpu.minor);
    if (gpu.major != 2 || gpu.minor != 1) {
        fprintf(stderr, "Expected compute capability 2.1 (sm_21)\n");
        return 1;
    }
    if (!check(cudaSetDevice(0), "Select device 0")) return 1;
    int *device = NULL;
    if (!check(cudaMalloc((void **)&device, sizeof(int)), "Allocate device memory")) return 1;
    int host = 0;
    write_value<<<1, 1>>>(device);
    bool ok = check(cudaGetLastError(), "Launch kernel")
        && check(cudaMemcpy(&host, device, sizeof(host), cudaMemcpyDeviceToHost), "Copy GPU result");
    bool freed = check(cudaFree(device), "Free device memory");
    if (!ok || !freed || host != 42) {
        fprintf(stderr, "CUDA calculation failed\n");
        return 1;
    }
    puts("CUDA kernel result verified: 42");
    return 0;
}
