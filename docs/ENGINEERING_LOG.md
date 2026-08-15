# Engineering log

How this port was actually built, including the wrong turns. If you are porting
something else to the Miyoo Mini, the dead ends are probably worth more than the
solutions — most of them cost days.

Written after the fact from the development notes; the ordering is roughly
chronological.

---

## 1. The linking problem, and why "just link statically" was the wrong answer

The first attempt cross-compiled against Debian's `armhf` SDL2 packages. That
produces a binary needing PulseAudio, JACK, DBus and X11 — none of which exist
on this device. Chasing the missing `.so` files is endless:

```
openclaw → libSDL2_mixer → libfluidsynth → libjack → libpulse → libpulsecommon
        → libdbus-1, libsndfile, libsystemd, libxcb, libwrap, liblz4, libgcrypt …
```

Static linking was suggested as the fix. It is not: it bakes in the *same*
dependencies, it just moves the failure from run time to link time. **The
problem is not how SDL2 is linked, it is which SDL2 is linked.**

The answer was on the SD card the whole time:
`/mnt/SDCARD/.tmp_update/lib/parasyte/libSDL2-2.0.so.0`, the device's own SDL2,
which needs only `libmi_ao`/`libmi_gfx`/`libmi_sys`, EGL/GLES and libc. Zero
PulseAudio, zero X11, zero DBus. Everything since is built against that.

Satellite libraries (`SDL2_image`, `SDL2_ttf`, `SDL2_mixer`, `SDL2_gfx`) are
compiled from source against it, with only the decoders that do not pull in a
desktop stack: WAV and OGG, PNG and PCX. PCX matters — the menus are PCX, and
the first build disabled it.

A related trap: the bundled SDL2 headers were 2.0.4 while the device library
exports 2.0.14+ symbols. `SDL2_mixer` will not build against the old headers.
Replacing just the sysroot headers with 2.0.20 is safe, since the SDL2 API is
additive.

## 2. The render backend was written for emulators, not for a 2D engine

The device's SDL2 has a custom `mmiyoo` render backend built around one
full-screen texture per frame — exactly what an emulator core needs. A sprite
engine breaks every assumption in it:

- a hard cap of 10 live textures;
- `QueueCopyEx` (mirroring) and `QueueFillRects` were no-ops;
- only one queued draw was ever presented per frame.

So the game ran, drew one thing per frame, and looked like a black screen. The
fix was to compile our own `libSDL2` from the [XK9274/sdl2_miyoo](https://github.com/XK9274/sdl2_miyoo)
fork with the backend rewritten to blit synchronously in draw order, with no
texture cap and with mirroring mapped onto `MI_GFX_Mirror_e`.

Several separate bugs hid behind that one:

- **The panel is mounted upside down**, so every blit applies a 180° rotation.
  `MI_GFX_BitBlit` rotates *within* the destination rectangle but does not move
  the rectangle, which is invisible for a full-screen blit and very visible for
  sprites. Destination coordinates have to be mirrored by hand.
- **`ARGB8888` was unreachable.** The driver declared
  `num_texture_formats = 2` with the formats at indices 0 and 2, so SDL only
  ever saw index 0 and 1. Every texture silently became `RGB565` without alpha —
  black boxes behind every piece of text.
- **Blits were never clipped to the screen.** A sprite at `x=620, w=64` becomes
  `x=-44` after the rotation, and a negative coordinate handed to the hardware
  blitter never returns. This is why the game froze the instant a scrolling
  level first drew, but never in a menu, where everything is on screen.
- Clipping then exposed two latent bugs in the staging path: rows were staged
  from the top of the texture while the hardware was told to read from
  `srcrect.y`, and the pixel format was inferred as `pitch / srcrect.w`, which
  stops being true for partial-width blits.

## 3. Memory: 100 MB total, and the engine assumes a desktop

`MemTotal` is 103360 kB. The OOM killer is a constant presence, and it lies
about the cause: an early "the level load hangs forever" turned out to be swap
thrashing, not a deadlock.

What actually helped, in order of effect:

- **Do not preload whole archives.** `VPreload("/CLAW/*")`, `/GAME/*`,
  `/STATES/*` and `/LEVELn/*` decode far more than the cache can hold; most of
  it is evicted before use, and the transient churn cost ~27 MB of permanent
  RSS. The actor loop lazy-loads what it needs anyway. Removing them took the
  startup footprint from ~62 MB to ~15 MB.
- **Release the raw level data after converting it.** `WwdToXml` builds an XML
  tree from the binary level; the binary is never touched again but sat in the
  cache competing with 1500 actor creations.
- **`ResourceCacheSize` = 16 MB.** 64 MB was simply too much on this device.

The general lesson: on this hardware, instrumentation has to be cheap or it
measures itself. An `fsync` per checkpoint costs ~72 ms here; 205 of them added
15 seconds to a 6 second load and produced the impression of a load-time bug
that did not exist.

## 4. Release builds drop asserts, and this engine leans on them

The first real gameplay crash was a null dereference in the Box2D contact
listener. Box2D can report a collision for a body whose actor is already gone;
one place in the listener handled it, and four others relied on `assert()` —
which does nothing in a Release build. The same class of bug turned up again in
the enemy AI.

Worth remembering when porting: `grep` for `assert(` in any path that can be
reached by ordinary gameplay.

## 5. The bugs that took the longest, and what finally found them

### Texture corruption, blamed on three innocent changes

Sprites came out as noise over correct geometry. Three separate attempts to warm
up assets during the loading screen were bisected on-device and each looked
guilty, so warm-up was abandoned twice.

The real cause: `PalResourceLoader::LoadAndReturnPal` hands out a raw pointer
into a `ResourceCache` entry, and the game holds it for the whole level while
nothing ever fetches it from the cache again. Its LRU entry therefore sits at the
tail and is the *first* thing evicted once the cache fills — after which every
sprite decodes its colours out of freed memory.

What settled it was warming **sounds only**. A WAV creates no texture, and the
textures still corrupted, which eliminated everything about image loading and
left cache pressure as the only variable.

### Sound lagging the action by about 0.7 s

Three rounds of "obvious" fixes changed nothing audible: a smaller SDL buffer, a
shorter MI_AO frame count, a lower mixer rate. Each time, the queue simply
refilled to the same ceiling.

`MMIYOO_PlayDevice` slept for a fixed *frame duration minus 10 ms* after each
`MI_AO_SendFrame`. A frame carries 23.2 ms of audio but was handed over every
~13 ms plus callback time, so the driver produced ~15% faster than the hardware
consumed. `MI_AO_QueryChnStat` showed the queue filling — 14544, 26752, 38968,
51176, 65024 bytes over five seconds — and then sitting pinned at its
65536-byte ceiling. A permanently full queue is a permanent delay of its entire
depth.

It now waits until the queue is down to about three frames. What made this
findable was a **standalone test program** (`tools/audio_latency_test.c`): press
a button, hear a beep, with no game, no SDL_mixer and no event queue in between.
It showed the software path taking ~20 ms, which moved the search below SDL —
and printing the return value of `MI_SYS_SetChnOutputPortDepth` revealed that
one of the earlier "fixes" had been rejected by the hardware all along
(`-1610014717`), silently, because nobody checked it.

### Audio assets are 22050 Hz mono; the mixer was opened at 44100 stereo

Every sound was resampled in software on load — ~110 ms per file regardless of
size, and again mid-frame the first time it played. Reading the WAV headers
straight out of `CLAW.REZ` confirmed the format. Matching the mixer to it cut
level loading from 29.2 s to 13.7 s and removed a whole class of stutter.

### The pause menu that "did not open"

It opened. `ScreenElementMenu::VSetVisible(true)` pauses the game logic, which
looked like a freeze, and the menu then drew nothing and swallowed no input,
because it was in no list: level transitions clear `m_ScreenElements` without
touching `m_pIngameMenu`, and the lazy initialiser only checked whether the
pointer was null. From level 2 on, the menu existed and belonged nowhere.

### Deaths that stopped working

Two variants, both found only after adding a `[DEATH]` log line — a death was
recorded nowhere, so two earlier diagnoses were guesses and both were wrong.

- `VOnHealthBelowZero` returns early while `ClawState_Dying`, and the physics
  callbacks (`VOnStartFalling`, `VOnLandOnGround`, `VOnStartJumping`) reset the
  state unconditionally. Drowning kept moving the body, the callbacks fired, and
  the death was cancelled mid-way: the player could run around inside the water.
  The guard existed everywhere the *player* could act, but not on the callbacks
  the world raises by itself.
- `ClawGameLogic::ClawDiedDelegate` never looked at the remaining lives, so it
  restored full health and teleported Claw to the checkpoint even on a game
  over, putting a healthy standing Claw behind the GAME OVER caption.

### A save file that stopped the game from starting

`<Health>4294967295</Health>`. Health is signed in the engine and deliberately
goes below zero (that is how death is detected), while the checkpoint struct
stores it unsigned. Loading used `std::stoi`, which throws on anything outside
`int`, and nothing catches it — so one bad number aborted the process before the
menu, and the only fix available to a player was deleting their save. Health is
now clamped when saving, and save values are parsed defensively.

## 6. Diagnostics that paid for themselves

Everything below is still in the shipped build, because none of it costs
anything until something goes wrong.

- **Crash handler.** A fatal signal writes the signal, the build id, what the
  game was doing, `pc`/`lr`, a backtrace and the memory map straight to the log
  with `write()` — no `printf`, no `malloc`, so it survives a crash inside the
  allocator. It runs on its own signal stack, so a stack overflow still produces
  a report. `tools/symbolize_crash.sh` turns the addresses back into function
  names, and warns if the binary does not match the report's build id.
- **A build id baked in from `git describe`**, printed at the top of every log
  and in every report. Crash addresses only resolve against the binary that
  produced them, and pointing `addr2line` at a different build produces
  confident nonsense rather than an error.
- **A watchdog thread** that turns a hang into a crash report: after 45 s
  without a main-loop tick it signals the *main* thread, so the backtrace shows
  where the game is stuck. This is how the level 12 hang was diagnosed — a
  freeze otherwise tells you nothing at all, because the player pulls the power
  and takes the answer with them.
- **Post-mortem in the launch script**: exit code, `free`, and the kernel ring
  buffer. An OOM kill cannot be caught in-process and says so only in `dmesg`.
- **Log rotation.** A crash is usually noticed after a restart, which used to
  truncate the log that explained it.

## 7. Levels 8–13

OpenClaw sets `lastImplementedLevel = 7`. The data for all 13 levels is present
— metadata, per-level actor prototypes, the enums, even the boss encounters that
only appear later — so the flag looks like caution rather than a hard limit.

Raising it and trying: levels 8 and 11 loaded and played, with enemies attacking
and mechanics working. Level 12 hung during loading, and the watchdog produced
the report: stuck in `TilePlaneRenderComponent::VDelegateInit`, with

```
VmPeak: 241916 kB    VmRSS: 73152 kB    VmSwap: 99136 kB
```

99 MB swapped out to the SD card on a 100 MB device. Not a missing-logic bug —
that level simply does not fit. A handful of decorative logics are unimplemented
(`Sign`, `Stalactite`, `Shake`, `CannonSwitch`, `AniCycleNormal`) and are skipped
with a warning.

So "implementing the later levels" is mostly a memory problem, not an engine
one: the XML DOM for a plane could be released as it is consumed, and the tile
list and image list need not both be resident.

## 8. Things still open

- Level 1 shows Claw's body after drowning. The engine supports one death effect
  per level and level 1 has both water and spikes; distinguishing them needs the
  death tile's type at the point of death.
- The resource cache is full after warm-up (16365/16384 kB), so some warmed
  sounds are evicted during the level and read again.
- One 688 ms frame was observed with no asset loading and no rendering work —
  time spent in the update phase, cause unknown.
- A short press on MENU does nothing; the GameSwitcher overlay expects to own
  the screen and the audio device, both of which the game holds.
