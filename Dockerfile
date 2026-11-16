FROM ubuntu:16.04@sha256:1f1a2d56de1d604801a9671f301190704c25d604a416f59e03c04f5c6ffee0d6
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates curl git && rm -rf /var/lib/apt/lists/*
COPY cuda/packages.sha256 /tmp/packages.sha256
RUN set -eux; cd /tmp; repo=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64; \
    while read -r hash file; do \
        curl -fsSL --retry 3 "$repo/$file" -o "$file"; \
        printf '%s  %s\n' "$hash" "$file" | sha256sum -c -; \
        dpkg-deb -x "$file" /; rm "$file"; \
    done < packages.sha256; rm packages.sha256; \
    ln -s /usr/local/cuda-8.0 /usr/local/cuda
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64
WORKDIR /opt/darknet
RUN git init && git fetch --depth=1 https://github.com/pjreddie/darknet.git f6afaabcdf85f77e7aff2ec55c020c0e297c77f9 && git checkout --detach FETCH_HEAD
RUN nvcc --version && mkdir -p obj && make -j2 darknet GPU=1 CUDNN=0 OPENCV=0 \
    ARCH="-gencode arch=compute_20,code=sm_21" \
    LDFLAGS="-lm -pthread -L/usr/local/cuda/lib64 -L/usr/local/cuda/lib64/stubs -lcuda -lcudart -lcublas -lcurand -lstdc++" \
    && cuobjdump -lelf ./darknet | grep sm_21
# Build the CPU comparison in an empty object directory.
RUN mkdir -p /tmp/darknet-cpu && git archive HEAD | tar -x -C /tmp/darknet-cpu \
    && cd /tmp/darknet-cpu && mkdir -p obj && make -j2 darknet GPU=0 CUDNN=0 OPENCV=0 \
    && mv darknet /opt/darknet/darknet-cpu && rm -rf /tmp/darknet-cpu
COPY cuda/probe.cu /tmp/probe.cu
RUN nvcc -gencode arch=compute_20,code=sm_21 -o cuda_probe /tmp/probe.cu \
    && cuobjdump -lelf ./cuda_probe | grep sm_21 && rm /tmp/probe.cu
ENTRYPOINT ["/opt/darknet/darknet"]
