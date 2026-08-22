# Changelog

Versions refer to the port, not to OpenClaw itself. Every build stamps its
version into the binary; it appears at the top of `log.txt` and in every crash
report, and crash addresses only resolve against the binary that produced them.

Only 1.2.3 onwards were released publicly.

Version numbers track *releases*, not commits. Local work accumulates under
Unreleased for as long as it takes — a hundred test builds still add up to one
version bump. When a release is actually wanted, Unreleased becomes the next
number after the last public one and is passed to `tools/sync_public.sh`, which
is the only thing that decides a version. Nothing derives it automatically.

Do not confuse this with the build ID stamped into each binary
(`git describe --always --tags`, e.g. `v1.2.4-2-gc3e1cc79`). That identifies the
exact binary a crash report came from and is *meant* to change every build; its
commit count is not a version.

## 1.2.5

**A movement and combat pass.** Everything here was found by playing on the
device and measured before it was changed; the numbers quoted are from the
device's own logs.

- Claw no longer slides off the edges of platforms. His collision body was a
  capsule, so his foot was a circle as wide as his shoulders; once his centre
  passed a platform corner it rested on that corner instead of the flat top and
  rolled him off. The foot is now a flat sole, as the 1997 original collided.
  Its lower corners are chamfered, which is what lets him cross the seams
  between ground tiles — a square sole caught on them and left him running on
  the spot
- Attacks no longer swallow input. Firing or swinging held the controls for the
  whole animation, long after the shot had left: on the pistol that is 500 ms of
  the 700 ms it runs, so ducking under a shot already on screen was impossible
  however early you reacted. Control now returns once the attack has landed,
  while the rate of attack stays exactly what it was — the two were the same
  value in the engine and are now separate
- Claw teeters on the lip of a platform, as the 1997 original does, and holds
  the pose until the player steps back or drops off. The animation and its sound
  were in `CLAW.REZ` and already loaded; nothing had ever played them.
  **Partial** — the wobble starts later than in the original, where Claw stands
  with a whole foot out over the edge. Usable, not finished
- The sword is worth what the stance is worth: double damage in the air, half
  crouched, as the 1997 original scores it. The engine only ever had the
  crouched case — a jumping swipe counted exactly like one from standing
- An attack pressed just before landing is no longer swallowed. It used to start
  its animation and be wiped by the landing before the hitbox ever appeared, so
  the press vanished with no swing and no sound; the swing is now carried over
  and finished on the ground. The same landing also left a cooldown running
  against an attack that no longer existed, which ate the *next* press too
- One enemy can no longer hurt you twice in quick succession. Enemies damage you
  both by swinging and by a contact aura that pulses on its own clock, and the
  aura fired the instant the post-hit invulnerability expired; an aura tick from
  an enemy that has already hurt you now waits for its next attack cycle. Other
  enemies standing around you are unaffected
- Killed enemies are thrown clear on an arc — up and away from Claw, then down
  off the screen — instead of sliding to the bottom right corner at a fixed
  speed regardless of where they were killed from
- **Standing too close to an enemy no longer makes the sword miss** — a
  deliberate change from the 1997 original, which behaved this way and was the
  harder for it. The swing was a 50 px box starting 35 px in front of Claw, and
  an enemy body is 40 px wide, so once Claw stood on top of one the swing began
  past it and passed straight through. The box now reaches back to his own body.
  Its forward reach is unchanged
- Weapon select moved from X to SELECT, which nothing used. X is now free
- Switching weapons makes a sound, the same click the menu uses, as the original
  does. It never had one: the HUD's ammo-change handler is an empty function and
  nothing else along that path said anything. The click is warmed during level
  loading now that it is no longer a menu-only sound

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
