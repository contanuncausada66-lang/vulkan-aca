FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility
ENV VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    sudo \
    libegl1 \
    libglvnd0 \
    libglx0 \
    libvulkan1 \
    vulkan-tools \
    libxext6 \
    ca-certificates \
    uidmap \
    dbus-user-session \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://code-server.dev/install.sh | sh

COPY test-userns.sh /test-userns.sh
RUN chmod +x /test-userns.sh

EXPOSE 8080

CMD ["/test-userns.sh"]
