=== Captain Claw (OpenClaw) for Miyoo Mini / Miyoo Mini Plus (OnionOS) ===

INSTALLING
1. Copy the `Roms` folder to the root of your SD card. You should end up with:
     /mnt/SDCARD/Roms/PORTS/Games/Captain Claw/
     /mnt/SDCARD/Roms/PORTS/Shortcuts/Action/Captain Claw.port

2. GAME DATA - you must supply this yourself:
   Copy CLAW.REZ from your own copy of the original Captain Claw (1997) into
     /mnt/SDCARD/Roms/PORTS/Games/Captain Claw/CLAW.REZ

3. The game appears under PORTS -> Action. If it does not show up, run
   "Import ports" in the PORTS menu once.

CONTROLS
   D-Pad        Move / duck / look up
   B            Jump
   Y            Attack (sword)
   A            Use weapon (pistol / dynamite / magic)
   X            Switch weapon
   START        Pause menu, and confirm in menus
   SELECT       Back / cancel in menus
   MENU (hold)  Quit to the launcher

WHAT WORKS
   Levels 1-7 (everything OpenClaw implements), sound effects, checkpoints and
   saves. Music is off: the game's music is MIDI and nothing in this build can
   play it.

IF THE GAME CLOSES BY ITSELF
   It leaves a short report on the card:
     /Roms/PORTS/Games/Captain Claw/crashlogs/crash-<date>-report.txt
   Please attach the newest one to a GitHub issue. It is a few kilobytes of
   plain text with no personal data in it. The last 10 crashes are kept.

   The dates are usually wrong (the console has no clock battery), but the
   ordering is right.

   If the game freezes instead of closing, power the console off and send
   log.txt from the game folder.

Have fun!
