#!/bin/bash
# Cross-compiles the patched "mmiyoo" SDL2 fork (sdl2-miyoo-src/, based on
# XK9274/sdl2_miyoo) against the Miyoo Mini toolchain. Produces our own
# libSDL2-2.0.so.0 with the render-backend fixes from PROJECT_STATUS.md:
# no texture cap, working QueueCopyEx (sprite mirroring)/QueueFillRects,
# synchronous per-draw-call blits instead of the single-framebuffer-only
# thread queue. Output goes to device-libs-upload/ for staging into the
# game's own lib/ folder — never touches the system libSDL2 in .tmp_update.
set -e

SRC=/src/sdl2-miyoo-src
TOOLCHAIN_SYSROOT=/opt/miyoomini-toolchain/usr/arm-linux-gnueabihf/sysroot
OUT=/output

export PATH="/opt/miyoomini-toolchain/usr/bin:${PATH}"
export CROSS=/opt/miyoomini-toolchain/usr/bin/arm-linux-gnueabihf-
export CC=${CROSS}gcc
export CXX=${CROSS}g++
export AR=${CROSS}ar
export AS=${CROSS}as
export LD=${CROSS}ld
# Not the same as autoconf's lowercase $host (from --host=...) — configure.ac's
# CheckMMiyooAudio specifically checks this uppercase $HOST shell var (set by
# the repo's own Makefile via "export HOST=arm-linux") to decide whether to
# link -lmi_ao/-lmi_sys/-lmi_gfx/etc at all. Without it the audio backend
# compiles but every MI_SYS_*/MI_GFX_* call is left undefined at link time.
export HOST=arm-linux

cd "$SRC/sdl2"

# Windows checkout adds CRLF line endings, which breaks the "#!/bin/sh" shebang
# (and bare $'\r' tokens) in every shell script in this tree.
# Note: this must catch include/SDL_config.h.in specifically — config.status
# substitutes "#undef NAME" -> "#define NAME VALUE" by literal line matching,
# and a stray \r on that line (as shipped) makes the match silently fail, so
# e.g. SDL_THREAD_PTHREAD stays "#undef" even though AC_DEFINE fired correctly
# during configure (confirmed via confdefs.h) — a #error deep in the audio
# build about "Need thread implementation for this platform" was the result.
find . -name "*.sh" -o -name "configure" -o -name "configure.ac" -o -name "mkinstalldirs" \
     -o -name "config.guess" -o -name "config.sub" -o -name "*.m4" -o -name "*.h.in" \
  | xargs -r sed -i 's/\r$//'

# Our own toolchain provides real libEGL.so.1/libGLESv2.so.2 pulled from the
# device (needed only to satisfy the linker — this build's SDL_VIDEODRIVER
# path never touches GLES) instead of the repo's expected /opt/mmiyoo layout.
mkdir -p /tmp/egl-libs
cp /device-libs/libEGL.so.1 /tmp/egl-libs/libEGL.so
cp /device-libs/libGLESv2.so.2 /tmp/egl-libs/libGLESv2.so

# configure.ac hardcodes -I/opt/mmiyoo/arm-buildroot-linux-gnueabihf/sysroot/usr/include/SDL2
# for the mmiyoo video/render backend (it #includes SDL_ttf.h/SDL_image.h from
# there). Point that exact path at the SDL2_ttf/image/mixer/gfx headers our own
# satellite build already staged into the toolchain sysroot.
mkdir -p /opt/mmiyoo/arm-buildroot-linux-gnueabihf/sysroot/usr/include
ln -sfn "$TOOLCHAIN_SYSROOT/usr/include/SDL2" /opt/mmiyoo/arm-buildroot-linux-gnueabihf/sysroot/usr/include/SDL2

rm -rf build Makefile config.status config.log include/SDL_config.h configure autom4te.cache

# The repo ships sdl2/libEGL.so and libGLESv2.so as symlinks into
# ../swiftshader/build/ (their software GL implementation, which we don't
# build or need). Git on Windows checks these out as literal text files
# containing the link target string instead of real symlinks — not a valid
# ELF, so linking against them ("-L." is in EXTRA_LDFLAGS) fails outright.
# Overwrite with our real device-pulled libs instead.
cp -f /device-libs/libEGL.so.1 libEGL.so
cp -f /device-libs/libGLESv2.so.2 libGLESv2.so

# Always regenerate configure + config.h.in from configure.ac/aclocal.m4 —
# the repo ships pre-generated copies that were mismatched (AC_DEFINE for
# SDL_THREAD_PTHREAD fired into confdefs.h but never made it into
# SDL_config.h, because the committed SDL_config.h.in's autoheader-managed
# substitution list didn't match this configure.ac).
./autogen.sh

MOD=mmiyoo \
EXTRA_LDFLAGS="-L/tmp/egl-libs -Wl,-rpath-link,/tmp/egl-libs" \
./configure \
    --host=arm-linux \
    --disable-joystick-virtual \
    --disable-jack \
    --disable-power \
    --disable-sensor \
    --disable-ime \
    --disable-dbus \
    --disable-fcitx \
    --disable-hidapi \
    --disable-libudev \
    --disable-video-x11 \
    --disable-video-kmsdrm \
    --disable-video-vulkan \
    --disable-video-opengl \
    --disable-video-opengles \
    --disable-video-opengles2 \
    --disable-video-wayland \
    --disable-video-dummy \
    --disable-oss \
    --disable-alsa \
    --disable-sndio \
    --disable-diskaudio \
    --disable-pulseaudio \
    --disable-dummyaudio

make -j$(nproc)

mkdir -p "$OUT"
cp -Pf build/.libs/libSDL2-2.0.so.0* "$OUT/"
arm-linux-gnueabihf-strip --strip-unneeded "$OUT/libSDL2-2.0.so.0"

# OpenClaw's build -I's $TOOLCHAIN_SYSROOT/usr/include/SDL2 (see
# miyoo_toolchain.cmake) — stage our platform extension header there too, so
# Image.cpp can #include "SDL_mmiyoo_ext.h" for MMIYOO_SetTextureColorKey.
cp -f include/SDL_mmiyoo_ext.h "$TOOLCHAIN_SYSROOT/usr/include/SDL2/"

echo "=== Built custom libSDL2-2.0.so.0 ==="
ls -la "$OUT/"
readelf -d "$OUT/libSDL2-2.0.so.0" | grep NEEDED
