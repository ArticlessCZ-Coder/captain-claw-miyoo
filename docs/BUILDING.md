# Building

Everything cross-compiles inside Docker, so the only prerequisites are Docker
and about 4 GB of disk. The build produces two artifacts: the game binary and a
patched `libSDL2`.

## 1. Libraries from your own console

Three libraries are needed to link against and are **not included here** — they
belong to OnionOS and to the device vendor, and redistributing them is not ours
to do. Copy them off your own console (FTP, SFTP or the SD card) into
`device-libs/`:

| File on the device | Copy to |
|---|---|
| `/mnt/SDCARD/.tmp_update/lib/parasyte/libSDL2-2.0.so.0` | `device-libs/libSDL2-2.0.so.0` |
| `/mnt/SDCARD/.tmp_update/lib/parasyte/libEGL.so.1` | `device-libs/libEGL.so.1` |
| `/mnt/SDCARD/.tmp_update/lib/parasyte/libGLESv2.so.2` | `device-libs/libGLESv2.so.2` |

Check the sizes after copying — a truncated `libSDL2` produces linker errors
about missing section headers rather than an honest failure.

## 2. The toolchain image

The Dockerfile pulls [shauninman's union-miyoomini-toolchain](https://github.com/shauninman/union-miyoomini-toolchain)
(GCC 8.3, Cortex-A7 sysroot) and builds the SDL2 satellite libraries
(`SDL2_image`, `SDL2_ttf`, `SDL2_mixer`, `SDL2_gfx`) against the device's own
`libSDL2`:

```sh
# Download toolchain/miyoomini-toolchain.tar.xz first - see the Dockerfile
docker build -f Dockerfile.miyoo -t openclaw-miyoo-builder .
```

Only WAV and OGG are enabled in `SDL2_mixer`, and only PNG plus PCX in
`SDL2_image`. That is deliberate: every other decoder drags in dependencies
(FluidSynth → JACK → PulseAudio → DBus) that do not exist on this device.

## 3. libSDL2

Clone [XK9274/sdl2_miyoo](https://github.com/XK9274/sdl2_miyoo) next to this
repository as `sdl2-miyoo-src/`, apply our patch, and build:

```sh
git clone https://github.com/XK9274/sdl2_miyoo sdl2-miyoo-src
git -C sdl2-miyoo-src apply ../patches/sdl2-miyoo-openclaw.patch
docker run --rm \
  -v "$PWD/sdl2-miyoo-src:/src/sdl2-miyoo-src" \
  -v "$PWD/device-libs:/device-libs" \
  -v "$PWD/device-libs-upload:/output" \
  -v "$PWD/build-scripts:/build-scripts" \
  openclaw-miyoo-builder bash /build-scripts/build_custom_sdl2.sh
```

The patch covers the render backend (blit clipping, mirroring, alpha, a staging
ring), the audio backend (output paced against the MI_AO queue) and the input
key table. What each change is for is explained in the comments it adds.

## 4. The game

Clone the engine fork as `openclaw-src/`, then:

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace openclaw-miyoo-builder \
  bash ./build_miyoo.sh
```

`build_miyoo.sh` stages the freshly built `libSDL2` and its header into the
sysroot before compiling, so the game is always built against the library it
ships with. It bakes a build id from `git describe` into the binary; that id
appears at the top of every log and in every crash report, and crash addresses
only resolve against the binary that produced them.

Strip before deploying, and **keep the unstripped copy** — it is what turns a
crash report back into function names:

```sh
cp Build_Release/openclaw Build_Release/openclaw.unstripped
arm-linux-gnueabihf-strip --strip-unneeded Build_Release/openclaw
```

## 5. Deploying

Copy `Build_Release/openclaw` and `device-libs-upload/libSDL2-2.0.so.0.18.2`
(as `lib/libSDL2-2.0.so.0`) into the game folder on the card.

## Reading a crash report

```sh
tools/symbolize_crash.sh crashlogs/crash-<date>-report.txt Build_Release/openclaw.unstripped
```

It resolves the report's addresses and warns if the binary does not match the
build id in the report — a mismatch silently produces plausible, wrong function
names, so the check matters.

## Diagnostics worth knowing about

- `MMIYOO_TEXLOG=1` — per-texture logging in the render backend.
- A watchdog thread turns a hung main loop into a crash report after 45 s, so a
  freeze produces a backtrace of the stuck thread instead of nothing.
- `config.xml` → `DebugOptions/LastImplementedLevel` unlocks levels past 7.
  They are untested; see the engineering log.
