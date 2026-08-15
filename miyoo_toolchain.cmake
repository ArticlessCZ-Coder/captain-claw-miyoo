set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(TOOLCHAIN_ROOT /opt/miyoomini-toolchain/usr)
set(CMAKE_SYSROOT ${TOOLCHAIN_ROOT}/arm-linux-gnueabihf/sysroot)

set(CMAKE_C_COMPILER ${TOOLCHAIN_ROOT}/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_ROOT}/bin/arm-linux-gnueabihf-g++)

set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Cortex-A7 (Miyoo Mini SigmaStar SSD202D)
# SDL2 + satellites (SDL2_gfx/SDL2_ttf/SDL2_image/SDL2_mixer) are cross-compiled
# into the sysroot's usr/include/SDL2 and usr/lib by build-scripts/build_sdl_satellites.sh,
# against the native device libSDL2-2.0.so.0 — not Debian armhf packages.
# -funwind-tables: keeps unwind info for every function (not just the ones with
# C++ exception edges) so the crash handler's backtrace() can walk more than the
# faulting frame. Costs a little binary size, no runtime cost, and it survives
# stripping since it lives in .ARM.exidx, not the symbol table.
set(CMAKE_C_FLAGS "-marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv7ve -funwind-tables -I${CMAKE_SYSROOT}/usr/include/SDL2")
set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS}")
# The device's libSDL2.so declares NEEDED on libEGL.so.1/libGLESv2.so.2 (real files
# exist on-device under Miyoo's own MI GPU stack, not in this build sysroot). They're
# only pulled in for GLES accelerated rendering paths OpenClaw doesn't use; tell the
# linker not to fail on undefined symbols originating from that indirect dependency.
# -lpthread: the watchdog uses pthread_kill to signal the main thread. SDL pulls
# pthread in for its own threads, but the game calls it directly, and in glibc
# 2.28 (this toolchain) pthread_kill still lives in libpthread, not libc.
set(CMAKE_EXE_LINKER_FLAGS "-L${CMAKE_SYSROOT}/usr/lib -lpthread -Wl,--allow-shlib-undefined -Wl,--unresolved-symbols=ignore-in-shared-libs")

# Do not bake build-machine paths into the binary (fixes the /workspace rpath issue)
set(CMAKE_SKIP_BUILD_RPATH ON)
set(CMAKE_SKIP_RPATH ON)

add_definitions(-DARM -DMIYOO_MINI)
