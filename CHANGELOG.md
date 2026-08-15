# Changelog

Versions refer to the port, not to OpenClaw itself. Every build stamps its
version into the binary; it appears at the top of `log.txt` and in every crash
report, and crash addresses only resolve against the binary that produced them.

Only 1.2.3 onwards were released publicly.

## 1.2.4

**Fixed a release blocker: the game could not start from a clean install.** The
package ships no save file — that is player state — and the engine treated a
missing one as fatal, exiting before drawing anything. Deleting the save to
reset progress was equally terminal.

- A missing or damaged save now means "no progress yet": a new game is
  initialised and the file is written at the next checkpoint
- The package ships a new-game save (level 1, checkpoint 0)

1.2.3 was withdrawn from the releases page.

## 1.2.3

- Drowning can no longer be "run out of". The physics callbacks
  (`VOnStartFalling`, `VOnLandOnGround`, `VOnStartJumping`) reset the actor state
  unconditionally and kept firing while Claw was dying, cancelling the death
  half-way and handing the controls back
- The last life no longer respawns behind the GAME OVER screen; Claw stays on
  the last frame of the death animation
- A corrupt save can no longer stop the game from starting. Health is signed in
  the engine and unsigned in the save, so a death could write `4294967295`,
  which the loader then threw on — before the menu, with no way for a player to
  recover but deleting their progress
- Picking a level OpenClaw does not implement returns to the menu instead of
  freezing
- Hold MENU to quit to the launcher, cleanly (settings are saved)
- Music that cannot play is no longer loaded at all — the MIDI read off the SD
  card was a visible stutter for no sound

## 1.2.2

- Claw stays down on the GAME OVER screen instead of standing back up
- The MENU button, and the first-powerup stutter (see 1.2.3, where the same
  areas were finished)

## 1.2.1

- Health is clamped when writing a checkpoint, and save values are parsed
  without exceptions

## 1.2

**The sound lag.** Output is now paced against the MI_AO queue instead of a
fixed sleep. The driver produced about 15% faster than the hardware consumed, so
the queue sat permanently full and every sound arrived roughly 0.7 s late — and
that is why shrinking buffers had never helped: the queue simply refilled.

- The mixer opens at 22050 Hz, the assets' own rate. No per-sound resampling:
  level loading went from 29.2 s to 13.7 s
- Effect sprites (explosions, pickup points, hit sparks, HUD digits) are warmed
  during the loading screen, which is where the mid-gameplay hitches came from
- The FPS and position overlays are off by default. The position readout rebuilt
  a text texture on *every frame*; turning both off halved the number of slow
  frames

Measured across one session: slow frames 106 → 23, time lost to them 5.9 s →
2.5 s, frames over 120 ms 12 → 5.

## 1.1

- **Texture corruption fixed** — the level palette is a raw pointer into a cache
  entry that nothing ever re-fetched, so it sat at the tail of the LRU list and
  was the first thing evicted once the cache filled. Every sprite then decoded
  its colours out of freed memory. Its handle is now pinned while in use
- Level sounds are warmed during loading

## 1.0

First playable build: levels 1–7, working sound, checkpoints and saves, the
pause menu, and crash reporting.

Getting there meant, among other things: building against the device's own SDL2
instead of Debian's (which drags in PulseAudio, JACK, DBus and X11), rewriting
the `mmiyoo` render backend — written for a single full-screen texture per frame
— to draw a sprite engine, clipping blits to the screen (an off-screen sprite
became a negative coordinate that the hardware blitter never returned from), and
cutting the startup footprint from ~62 MB to ~15 MB on a 100 MB device.

The [engineering log](docs/ENGINEERING_LOG.md) has the full account, including
the wrong turns.
