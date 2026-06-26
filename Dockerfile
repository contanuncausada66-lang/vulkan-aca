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
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN echo '#!/bin/bash\n\
echo "=== Testing user namespace support ==="\n\
echo "1. kernel.unprivileged_userns_clone:"\n\
cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "  not available"\n\
echo "2. user.max_user_namespaces:"\n\
sysctl user.max_user_namespaces 2>/dev/null || echo "  not available"\n\
echo "3. Testing unshare --user:"\n\
unshare --user --map-root-user echo "  SUCCESS: user namespace works!" 2>&1 || echo "  FAILED"\n\
echo "4. Current capabilities:"\n\
cat /proc/self/status | grep -i cap\n\
echo "5. Testing CLONE_NEWUSER via python:"\n\
python3 -c \"import ctypes; libc = ctypes.CDLL('libc.so.6'); CLONE_NEWUSER = 0x10000000; result = libc.unshare(CLONE_NEWUSER); print(f'  unshare result: {result}')\" 2>&1 || echo "  python3 not available"\n\
echo "=== Done ==="\n\
exec code-server --bind-addr 0.0.0.0:8080 --auth none\n' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
