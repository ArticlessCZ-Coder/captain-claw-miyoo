# Licences

This repository contains the packaging, build system, documentation and patches
for the port. The components it builds have their own licences:

| Component | Licence | Where |
|---|---|---|
| OpenClaw engine (and our fork of it) | GPLv3 | https://github.com/pjasicek/OpenClaw |
| SDL2, and the `sdl2_miyoo` fork | zlib | https://github.com/XK9274/sdl2_miyoo |
| Our SDL changes (`patches/`) | zlib, as derivative of the above | this repository |

The shipped `openclaw` binary is built from GPLv3 sources; the corresponding
modified sources are published, as that licence requires — see the README for
the link.

`CLAW.REZ`, the artwork, sound and level data of *Captain Claw* (1997), is
© Monolith Productions and is **not** distributed here in any form. Players must
supply their own copy.

The libraries under `MiyooMiniPackage/.../lib/` that were compiled by this
project (`libSDL2`, `SDL2_image`, `SDL2_ttf`, `SDL2_mixer`, `SDL2_gfx`, `libogg`,
`libvorbis`) are zlib/BSD-licensed upstream projects built from source. The
device's own vendor libraries are deliberately not included.
