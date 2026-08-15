# Reporting a crash

If the game closes back to the launcher on its own, it left a report on the SD
card. Sending that file is the single most useful thing you can do — without it
a crash report is a guess.

## Where the file is

```
/mnt/SDCARD/Roms/PORTS/Games/Captain Claw/crashlogs/
```

Take the newest `crash-<date>-report.txt`. It is a few kilobytes of plain text
and you can read it yourself. Attach it to a new issue using the
**Crash report** template.

The folder also holds a matching `crash-<date>-log.txt` — the full game log.
Attach it too if you have it; it is bigger but sometimes shows what happened in
the seconds before the crash. Only the last 10 crashes are kept.

Note that the dates are usually wrong (the console has no clock battery), but
the ordering is right.

## What the file contains

Nothing personal: the signal that killed the game, what the game was doing
(menu / loading level / gameplay), CPU register values, a list of addresses,
where the game and its libraries were loaded in memory, how much memory was
free, and the last 40 lines of the game log. No file names from your card, no
network information, no identifiers.

## What we do with it

The addresses are meaningless on their own — they only resolve against the exact
binary that produced them, which is why the report starts with a `build:` line.
Every release publishes the debug binary (`openclaw.unstripped`) next to the
game, so:

```sh
tools/symbolize_crash.sh crash-19700108-071109-report.txt openclaw.unstripped
```

prints the function and source line where the game died. Using a binary from a
different build does not error — it silently prints the wrong functions — so the
script checks the `build:` line against the binary and warns on a mismatch.

## If the game hangs instead of closing

A frozen game leaves no report (nothing crashed). Power the console off, then
send `log.txt` from the game folder — it is written line by line as the game
runs, so its ending shows how far the game got.
