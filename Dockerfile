FROM ubuntu:16.04
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates curl git && rm -rf /var/lib/apt/lists/*
RUN set -eux; repo=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64; \
    for pkg in core misc-headers driver-dev command-line-tools cudart cudart-dev cublas cublas-dev curand curand-dev; do \
        file=cuda-${pkg}-8-0_8.0.61-1_amd64.deb; \
        curl -fsSL --retry 3 "$repo/$file" -o "/tmp/$file"; \
        dpkg-deb -x "/tmp/$file" /; rm "/tmp/$file"; \
    done; ln -s /usr/local/cuda-8.0 /usr/local/cuda
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64
WORKDIR /opt/darknet
RUN git init && git fetch --depth=1 https://github.com/pjreddie/darknet.git f6afaabcdf85f77e7aff2ec55c020c0e297c77f9 && git checkout --detach FETCH_HEAD
RUN nvcc --version && mkdir -p obj && make -j2 darknet GPU=1 CUDNN=0 OPENCV=0 \
    ARCH="-gencode arch=compute_20,code=sm_21" \
    LDFLAGS="-lm -pthread -L/usr/local/cuda/lib64 -L/usr/local/cuda/lib64/stubs -lcuda -lcudart -lcublas -lcurand -lstdc++" \
    && cuobjdump -lelf ./darknet | grep sm_21
ENTRYPOINT ["/opt/darknet/darknet"]
