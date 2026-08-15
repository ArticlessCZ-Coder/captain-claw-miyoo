#!/bin/bash
# Cross-compiles SDL2_gfx, SDL2_ttf, SDL2_image (PNG only), SDL2_mixer (WAV+OGG only)
# against the native Miyoo Mini libSDL2-2.0.so.0 (device-libs/), using the
# union-miyoomini-toolchain (GCC 8.3, sysroot has libpng/libfreetype/libz already).
#
# Deliberately excludes JPEG/WEBP/TIF (SDL2_image) and MOD/MIDI/FLAC/MP3/FluidSynth/
# JACK/PulseAudio/DBus (SDL2_mixer) — those are the desktop-dependency cascade this
# whole port exists to avoid. Only WAV + OGG music are enabled.
set -e

SYSROOT=/opt/miyoomini-toolchain/usr/arm-linux-gnueabihf/sysroot
PREFIX=$SYSROOT/usr
HOST=arm-linux-gnueabihf
JOBS=$(nproc)

export PATH="/opt/miyoomini-toolchain/usr/bin:${PATH}"
export CC=${HOST}-gcc
export CXX=${HOST}-g++
export CFLAGS="-marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -march=armv7ve -I${PREFIX}/include -I${PREFIX}/include/SDL2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"

mkdir -p /work
cd /work

# --- Stage SDL2 itself into the sysroot: native .so + matching headers ---
# The device .so exports symbols added in SDL 2.0.14-2.0.18 (SDL_AudioStream,
# SDL_RenderGeometry, SDL_GameControllerGetTouchpadFinger, SDL_HasAVX512F) — the
# game's bundled ThirdParty/SDL2 headers are only 2.0.4 and lack these, which
# breaks building SDL2_mixer (uses SDL_AudioStream internally). Use real 2.0.20
# headers instead (SDL2 keeps a stable/additive public API, so this is safe).
mkdir -p "$PREFIX/include/SDL2" "$PREFIX/lib"
cp -f /device-libs/libSDL2-2.0.so.0 "$PREFIX/lib/"
ln -sf libSDL2-2.0.so.0 "$PREFIX/lib/libSDL2.so"
ln -sf libSDL2-2.0.so.0 "$PREFIX/lib/libSDL2-2.0.so"
if [ ! -f "$PREFIX/include/SDL2/.headers-2.0.20" ]; then
  mkdir -p /work/sdl2-headers && cd /work/sdl2-headers
  [ -f SDL2-2.0.20.tar.gz ] || wget --timeout=60 -q -O SDL2-2.0.20.tar.gz https://www.libsdl.org/release/SDL2-2.0.20.tar.gz
  tar xf SDL2-2.0.20.tar.gz
  cp -f SDL2-2.0.20/include/*.h "$PREFIX/include/SDL2/"
  touch "$PREFIX/include/SDL2/.headers-2.0.20"
fi
cd /work
mkdir -p "$PREFIX/lib/pkgconfig"
cat > "$PREFIX/lib/pkgconfig/sdl2.pc" << PCEOF
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/SDL2

Name: sdl2
Description: Simple DirectMedia Layer (native Miyoo build)
Version: 2.0.4
Libs: -L\${libdir} -lSDL2
Cflags: -I\${includedir}
PCEOF
cat > "$PREFIX/bin-sdl2-config" << 'EOF'
EOF
mkdir -p "$PREFIX/bin"
cat > "$PREFIX/bin/sdl2-config" << CFGEOF
#!/bin/sh
case "\$1" in
  --prefix) echo "${PREFIX}" ;;
  --cflags) echo "-I${PREFIX}/include/SDL2" ;;
  --libs) echo "-L${PREFIX}/lib -lSDL2" ;;
  *) echo "Usage: \$0 [--prefix|--cflags|--libs]"; exit 1 ;;
esac
CFGEOF
chmod +x "$PREFIX/bin/sdl2-config"

echo "=== SDL2 staged in sysroot ==="

# --- libogg ---
if [ ! -f "$PREFIX/lib/libogg.so" ]; then
  cd /work
  [ -f libogg-1.3.5.tar.gz ] || wget -q https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz
  tar xf libogg-1.3.5.tar.gz
  cd libogg-1.3.5
  ./configure --host=$HOST --prefix=$PREFIX --enable-shared --disable-static
  make -j$JOBS
  make install
fi

# --- libvorbis ---
if [ ! -f "$PREFIX/lib/libvorbis.so" ]; then
  cd /work
  [ -f libvorbis-1.3.7.tar.gz ] || wget -q https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz
  tar xf libvorbis-1.3.7.tar.gz
  cd libvorbis-1.3.7
  ./configure --host=$HOST --prefix=$PREFIX --with-ogg=$PREFIX --enable-shared --disable-static
  make -j$JOBS
  make install
fi

# --- SDL2_gfx ---
if [ ! -f "$PREFIX/lib/libSDL2_gfx.so" ]; then
  cd /work
  [ -d SDL2_gfx-1.0.4 ] || { wget -q "https://sourceforge.net/projects/sdl2gfx/files/SDL2_gfx-1.0.4.tar.gz/download" -O sdl2_gfx.tar.gz && tar xf sdl2_gfx.tar.gz; }
  cd SDL2_gfx-1.0.4
  ./configure --host=$HOST --prefix=$PREFIX SDL2_CONFIG=$PREFIX/bin/sdl2-config --enable-shared --disable-static --disable-mmx
  make -j$JOBS
  make install
fi

# --- SDL2_ttf ---
if [ ! -f "$PREFIX/lib/libSDL2_ttf.so" ]; then
  cd /work
  [ -f SDL2_ttf-2.0.15.tar.gz ] || wget -q https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.15.tar.gz
  tar xf SDL2_ttf-2.0.15.tar.gz
  cd SDL2_ttf-2.0.15
  FT2_CFLAGS="-I${PREFIX}/include/freetype2" FT2_LIBS="-L${PREFIX}/lib -lfreetype" \
  ./configure --host=$HOST --prefix=$PREFIX SDL2_CONFIG=$PREFIX/bin/sdl2-config --enable-shared --disable-static
  # Only build the library itself — the bundled showfont/glfont demo apps fail to
  # link because they need libEGL/libGLESv2, which aren't in the cross sysroot and
  # aren't needed by OpenClaw. Install manually to skip `make install`'s all-am dep.
  make -j$JOBS libSDL2_ttf.la
  cp -Pf .libs/libSDL2_ttf*.so* "$PREFIX/lib/"
  cp -f SDL_ttf.h "$PREFIX/include/SDL2/"
  cp -f SDL2_ttf.pc "$PREFIX/lib/pkgconfig/" 2>/dev/null || true
fi

# --- SDL2_image (PNG + PCX — the engine calls IMG_LoadPCX_RW/IMG_LoadPNG_RW
#     directly, see Engine/Graphics2D/Image.cpp; PCX menu/UI art comes from
#     CLAW.REZ. PCX needs no external lib, unlike jpg/tif/webp which stay off.) ---
if [ ! -f "$PREFIX/lib/libSDL2_image.so" ]; then
  cd /work
  [ -f SDL2_image-2.0.5.tar.gz ] || wget -q https://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.5.tar.gz
  tar xf SDL2_image-2.0.5.tar.gz
  cd SDL2_image-2.0.5
  ./configure --host=$HOST --prefix=$PREFIX SDL2_CONFIG=$PREFIX/bin/sdl2-config \
    --enable-shared --disable-static \
    --enable-png --enable-pcx --disable-jpg --disable-tif --disable-webp --disable-bmp \
    --disable-gif --disable-lbm --disable-pnm --disable-svg \
    --disable-xcf --disable-xpm --disable-xv --disable-jpg-shared --disable-png-shared
  make -j$JOBS libSDL2_image.la
  cp -Pf .libs/libSDL2_image*.so* "$PREFIX/lib/"
  cp -f SDL_image.h "$PREFIX/include/SDL2/"
  cp -f SDL2_image.pc "$PREFIX/lib/pkgconfig/" 2>/dev/null || true
fi

# --- SDL2_mixer (WAV + OGG only) ---
if [ ! -f "$PREFIX/lib/libSDL2_mixer.so" ]; then
  cd /work
  [ -f SDL2_mixer-2.0.4.tar.gz ] || wget -q https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.4.tar.gz
  tar xf SDL2_mixer-2.0.4.tar.gz
  cd SDL2_mixer-2.0.4
  ./configure --host=$HOST --prefix=$PREFIX SDL2_CONFIG=$PREFIX/bin/sdl2-config \
    --enable-shared --disable-static \
    --enable-music-ogg --disable-music-ogg-shared \
    --disable-music-mod --disable-music-mod-modplug --disable-music-midi-fluidsynth \
    --disable-music-opus --disable-music-flac --disable-music-mp3 --disable-music-mp3-mad-gpl \
    --disable-music-midi --disable-music-timidity-midi \
    --with-ogg-prefix=$PREFIX --with-vorbis-prefix=$PREFIX
  # Hand-written (non-Automake) Makefile: install-lib builds+installs just the
  # library, skipping playwave/playmus demo apps (which need EGL, unavailable
  # in this sysroot and unneeded by OpenClaw).
  make -j$JOBS install-lib install-hdrs
fi

echo "=== All SDL2 satellite libraries built ==="
find "$PREFIX/lib" -maxdepth 1 -name '*.so*' -newer /work
