#!/bin/bash
echo "=== User Namespace Test ===" | tee /test-results.txt
echo "1. kernel.unprivileged_userns_clone:" | tee -a /test-results.txt
cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null | tee -a /test-results.txt || echo "  not available" | tee -a /test-results.txt
echo "2. user.max_user_namespaces:" | tee -a /test-results.txt
sysctl user.max_user_namespaces 2>/dev/null | tee -a /test-results.txt || echo "  not available" | tee -a /test-results.txt
echo "3. Testing unshare --user:" | tee -a /test-results.txt
unshare --user --map-root-user echo "  SUCCESS: user namespace works!" 2>&1 | tee -a /test-results.txt || echo "  FAILED" | tee -a /test-results.txt
echo "4. Current capabilities:" | tee -a /test-results.txt
cat /proc/self/status | grep -i cap | tee -a /test-results.txt
echo "5. Testing CLONE_NEWUSER via python3 ctypes:" | tee -a /test-results.txt
python3 << 'PYEOF' 2>&1 | tee -a /test-results.txt
import ctypes, os
libc = ctypes.CDLL('libc.so.6', use_errno=True)
CLONE_NEWUSER = 0x10000000
result = libc.unshare(CLONE_NEWUSER)
errno_val = ctypes.get_errno()
if result == 0:
    print(f'  unshare result: {result}, errno: {errno_val} - SUCCESS')
else:
    print(f'  FAILED: errno={errno_val} ({os.strerror(errno_val)})')
PYEOF
echo "6. Testing clone with CLONE_NEWUSER:" | tee -a /test-results.txt
python3 << 'PYEOF' 2>&1 | tee -a /test-results.txt
import ctypes, os, signal
libc = ctypes.CDLL('libc.so.6', use_errno=True)
CLONE_NEWUSER = 0x10000000
STACK_SIZE = 1024 * 1024
stack = ctypes.create_string_buffer(STACK_SIZE)
stack_top = ctypes.cast(ctypes.addressof(stack) + STACK_SIZE, ctypes.c_void_p)
def child_func(arg):
    print(f'  Child PID: {os.getpid()}, UID: {os.getuid()}')
    return 0
CHILD_FUNC = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)(child_func)
result = libc.clone(CHILD_FUNC, stack_top, CLONE_NEWUSER | signal.SIGCHLD, None)
if result == -1:
    errno_val = ctypes.get_errno()
    print(f'  clone FAILED: errno={errno_val} ({os.strerror(errno_val)})')
else:
    os.waitpid(result, 0)
    print(f'  clone SUCCESS: child PID={result}')
PYEOF
echo "=== End Test ===" | tee -a /test-results.txt
exec code-server --bind-addr 0.0.0.0:8080 --auth none
