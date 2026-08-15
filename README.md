# Captain Claw for Miyoo Mini (OnionOS)

A port of [OpenClaw](https://github.com/pjasicek/OpenClaw) — the open-source
reimplementation of *Captain Claw* (Monolith, 1997) — to the Miyoo Mini and
Miyoo Mini Plus running OnionOS.

**You need your own copy of the original game.** `CLAW.REZ` from a legitimate
Captain Claw installation is not included here and never will be.

---

## Status

Levels 1–7 are implemented by OpenClaw itself and are playable here start to
finish. What that means in practice on this device:

| Works | Notes |
|---|---|
| Levels 1–7 | Load in ~14 s, run at a steady frame rate |
| Sound effects | 22050 Hz, matching the game's own assets |
| Checkpoints and saves | Progress persists between sessions |
| Pause menu (START) | Resume / end life / end game |
| Controls | See below |
| Crash reporting | A crash writes a small report you can attach to an issue |

| Does not work | Why |
|---|---|
| Music | The game's music is MIDI (`.XMI`). SDL_mixer is built without a synthesiser on purpose — FluidSynth would drag in the JACK/PulseAudio stack this port exists to avoid. Music is off in `config.xml`. |
| Levels 8–13 | Not implemented by OpenClaw upstream. The data exists and levels 8–11 appear to run when unlocked, but they are untested and unsupported; level 12 exceeds the device's memory and hangs while loading. See [docs/ENGINEERING_LOG.md](docs/ENGINEERING_LOG.md). |
| GameSwitcher on MENU | A short press does nothing; the switcher expects to own the screen and audio device while the game holds both. Hold MENU to exit instead. |

Known rough edges: on level 1 the body stays visible after drowning (the engine
supports one death effect per level, and level 1 has both water and spikes), and
a handful of decorative objects are skipped because their game logic is not
implemented upstream (`Sign`, `Stalactite`, `Shake`, …).

---

## Installing

1. Copy the contents of `MiyooMiniPackage/` onto the root of your SD card. You
   should end up with:

   ```
   /Roms/PORTS/Games/Captain Claw/
   /Roms/PORTS/Shortcuts/Action/Captain Claw.port
   ```

2. Copy `CLAW.REZ` from your own copy of the original game into:

   ```
   /Roms/PORTS/Games/Captain Claw/CLAW.REZ
   ```

3. Start the console. "Captain Claw" appears under **PORTS → Action**. If it does
   not, run **Import ports** in the PORTS menu once.

The game ships with its own `libSDL2` and satellite libraries in `lib/`, used
ahead of the system ones through `LD_LIBRARY_PATH`. Nothing outside the game's
own folder is modified.

## Controls

| Button | Action |
|---|---|
| D-Pad | Move, duck, look up |
| B | Jump |
| Y | Attack (sword) |
| A | Use weapon (pistol / dynamite / magic) |
| X | Switch weapon |
| START | Pause menu; also confirms in menus |
| SELECT | Back / cancel in menus |
| MENU (hold) | Quit to the launcher, saving settings |

---

## Reporting a crash

If the game closes on its own, it leaves a short report on the SD card:

```
/Roms/PORTS/Games/Captain Claw/crashlogs/crash-<date>-report.txt
```

**Attach the newest one to a new issue.** It is a few kilobytes of plain text
you can read yourself: the signal, the build, what the game was doing, and a
list of addresses. No personal data, no file names from your card, no network
information. Full details, including what to send when the game *hangs* rather
than closes, are in [docs/REPORTING_CRASHES.md](docs/REPORTING_CRASHES.md).

The dates in those file names are usually wrong — the console has no clock
battery — but the ordering is right.

---

## Building

See [docs/BUILDING.md](docs/BUILDING.md). Everything cross-compiles in Docker;
the one manual step is pulling three libraries off your own console, which are
deliberately not redistributed here.

## Version history

[CHANGELOG.md](CHANGELOG.md) — what changed in each version, and why.

## How this was made

The port was built by [ArticlessCZ-Coder](https://github.com/ArticlessCZ-Coder)
together with [Claude](https://claude.com/claude-code) (Anthropic), which did
most of the engineering: the cross-build against the device's own SDL2, the
render and audio backend work, the memory reductions needed to fit a 100 MB
device, and the crash and hang diagnostics.

All of it was directed and verified on real hardware by the maintainer, and that
part was not a formality — most of the bugs that got fixed were found by playing
the game rather than by reading the code, several of them right after a
confident "this should work now". The first public release could not start from
a clean install, and it took a user following the published instructions to find
out.

The [engineering log](docs/ENGINEERING_LOG.md) keeps the wrong turns alongside
the fixes, including the diagnoses that were confidently wrong until a
measurement said otherwise.

## Credits and licences

- [OpenClaw](https://github.com/pjasicek/OpenClaw) by Petr Jašíček and
  contributors — GPLv3. The engine changes made for this port are published at
  [openclaw-miyoo](https://github.com/ArticlessCZ-Coder/openclaw-miyoo), as that
  licence requires.
- [sdl2_miyoo](https://github.com/XK9274/sdl2_miyoo) by XK9274, itself based on
  Steward Fu's Miyoo SDL2 — zlib. Our changes to it are in
  [`patches/sdl2-miyoo-openclaw.patch`](patches/sdl2-miyoo-openclaw.patch).
- SDL2 by Sam Lantinga and contributors — zlib.
- *Captain Claw* is © Monolith Productions. This project ships none of its data.
