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

RUN echo '#!/bin/bash\n\
echo "=== User Namespace Test ===" > /test-results.txt\n\
echo "1. kernel.unprivileged_userns_clone:" | tee -a /test-results.txt\n\
cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null | tee -a /test-results.txt || echo "  not available" | tee -a /test-results.txt\n\
echo "2. user.max_user_namespaces:" | tee -a /test-results.txt\n\
sysctl user.max_user_namespaces 2>/dev/null | tee -a /test-results.txt || echo "  not available" | tee -a /test-results.txt\n\
echo "3. Testing unshare --user:" | tee -a /test-results.txt\n\
unshare --user --map-root-user echo "  SUCCESS: user namespace works!" 2>&1 | tee -a /test-results.txt || echo "  FAILED" | tee -a /test-results.txt\n\
echo "4. Current capabilities:" | tee -a /test-results.txt\n\
cat /proc/self/status | grep -i cap | tee -a /test-results.txt\n\
echo "5. Testing CLONE_NEWUSER via python3 ctypes:" | tee -a /test-results.txt\n\
python3 -c \"import ctypes, os; libc = ctypes.CDLL('libc.so.6', use_errno=True); CLONE_NEWUSER = 0x10000000; result = libc.unshare(CLONE_NEWUSER); errno = ctypes.get_errno(); print(f'  unshare result: {result}, errno: {errno}') if result == 0 else print(f'  FAILED: errno={errno} ({os.strerror(errno)})')\" 2>&1 | tee -a /test-results.txt\n\
echo "6. Testing clone with CLONE_NEWUSER:" | tee -a /test-results.txt\n\
python3 -c \"\n\
import ctypes, os, struct, signal\n\
libc = ctypes.CDLL('libc.so.6', use_errno=True)\n\
CLONE_NEWUSER = 0x10000000\n\
STACK_SIZE = 1024 * 1024\n\
stack = ctypes.create_string_buffer(STACK_SIZE)\n\
stack_top = ctypes.cast(ctypes.addressof(stack) + STACK_SIZE, ctypes.c_void_p)\n\
def child_func(arg):\n\
    print(f'  Child PID: {os.getpid()}, UID: {os.getuid()}')\n\
    return 0\n\
CHILD_FUNC = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)(child_func)\n\
result = libc.clone(CHILD_FUNC, stack_top, CLONE_NEWUSER | signal.SIGCHLD, None)\n\
if result == -1:\n\
    errno = ctypes.get_errno()\n\
    print(f'  clone FAILED: errno={errno} ({os.strerror(errno)})')\n\
else:\n\
    os.waitpid(result, 0)\n\
    print(f'  clone SUCCESS: child PID={result}')\n\
\" 2>&1 | tee -a /test-results.txt\n\
echo "=== End Test ===" | tee -a /test-results.txt\n\
exec code-server --bind-addr 0.0.0.0:8080 --auth none\n' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 8080

CMD ["/entrypoint.sh"]
