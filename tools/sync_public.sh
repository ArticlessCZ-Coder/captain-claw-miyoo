#!/bin/bash
# Syncs the working repositories into the public ones and commits there.
#
# The public repos deliberately have their own, clean history with an anonymous
# author - the working repos carry the maintainer's real git identity in every
# commit. This script is the bridge: it copies only the files that are allowed
# out, regenerates the SDL patch, and commits under the public identity. Run it
# from the root of the working repository.
#
#   tools/sync_public.sh              # sync + commit
#   tools/sync_public.sh v1.3         # sync + commit + tag
#
# It never pushes. Review, then push.

set -e

WORK_DIR="$(pwd)"
PUBLIC_DIR="${PUBLIC_DIR:-$(dirname "$WORK_DIR")/captain-claw-miyoo-publish}"
PUBLIC_NAME="Captain Claw Miyoo Port"
PUBLIC_EMAIL="noreply@users.noreply.github.com"
TAG="$1"

if [ ! -d "$PUBLIC_DIR/captain-claw-miyoo/.git" ]; then
    echo "error: no public repo at $PUBLIC_DIR/captain-claw-miyoo" >&2
    echo "       set PUBLIC_DIR if it lives somewhere else" >&2
    exit 1
fi

# Everything not on this list goes public, so the list is the security boundary:
# device address and credentials, the player's own save, vendor blobs pulled off
# a console, the local build tree, and the Czech-language internal log (the
# public repo carries the translated docs/ENGINEERING_LOG.md instead).
EXCLUDE='^\.vscode/|^device-libs/|SAVES\.XML|^Build_Release/|Claw Audio Test\.port|launch_audiotest\.sh|^PROJECT_STATUS\.md|^device-libs-upload/libSDL2-2\.0\.so\.0$'

# Files the public repo owns its own version of, which a plain copy would
# clobber: the player-facing README is English there and Czech here, and the
# ignore rules differ (the public one also excludes saves and vendor blobs).
EXCLUDE="$EXCLUDE"'|^\.gitignore$|^MiyooMiniPackage/Roms/PORTS/Games/Captain Claw/README\.txt$'

echo "== main repo"
git ls-files | grep -vE "$EXCLUDE" > /tmp/sync-files.txt
tar -cf - -T /tmp/sync-files.txt | (cd "$PUBLIC_DIR/captain-claw-miyoo" && tar -xf -)

# The published config must not carry experiment settings.
sed -i 's|<LastImplementedLevel>[0-9]*</LastImplementedLevel>|<LastImplementedLevel>7</LastImplementedLevel>|' \
    "$PUBLIC_DIR/captain-claw-miyoo/MiyooMiniPackage/Roms/PORTS/Games/Captain Claw/config.xml"

echo "== SDL patch"
# Regenerated rather than copied: the public side ships our changes as a patch
# against upstream, because the fork itself is 1.5 GB (it vendors SwiftShader).
SDL_UPSTREAM_BASE="${SDL_UPSTREAM_BASE:-bf1aba2d}"
git -C sdl2-miyoo-src diff "$SDL_UPSTREAM_BASE"..HEAD -- sdl2/src sdl2/include mmiyoo \
    > "$PUBLIC_DIR/captain-claw-miyoo/patches/sdl2-miyoo-openclaw.patch"

echo "== engine fork"
(cd openclaw-src && git ls-files > /tmp/sync-oc.txt && tar -cf - -T /tmp/sync-oc.txt) \
    | (cd "$PUBLIC_DIR/openclaw-miyoo" && tar -xf -)

echo "== checking for anything that should not be published"
# The patterns are derived at run time, never written down here: this script is
# itself published, so a hardcoded list of "things that must not appear" would
# be the leak it is meant to prevent.
#
# Deliberately narrow, too - the device's own address rather than "any private
# IP", because upstream Tinyxml's tutorial uses 192.168.0.1 as an example and a
# check that cries wolf gets ignored after the third false alarm.
PATTERNS=""
if [ -f .vscode/sftp.json ]; then
    DEVICE_HOST=$(sed -n 's/.*"host"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .vscode/sftp.json)
    [ -n "$DEVICE_HOST" ] && PATTERNS="$PATTERNS $(echo "$DEVICE_HOST" | sed 's/\./\\./g')"
fi
GIT_EMAIL=$(git config user.email 2>/dev/null)
[ -n "$GIT_EMAIL" ] && PATTERNS="$PATTERNS ${GIT_EMAIL%%@*}"
[ -n "$HOME" ] && PATTERNS="$PATTERNS Users.$(basename "$HOME")"

FOUND=0
for pattern in $PATTERNS; do
    if grep -rIl "$pattern" "$PUBLIC_DIR" --exclude-dir=.git 2>/dev/null | grep -q .; then
        echo "REFUSING: '$pattern' appears in the public tree:" >&2
        grep -rIl "$pattern" "$PUBLIC_DIR" --exclude-dir=.git 2>/dev/null | head >&2
        FOUND=1
    fi
done
[ "$FOUND" = "0" ] || exit 1

MESSAGE="${TAG:+Release $TAG}"
MESSAGE="${MESSAGE:-Sync from development}"

for repo in captain-claw-miyoo openclaw-miyoo; do
    cd "$PUBLIC_DIR/$repo"

    if [ -z "$(git status --porcelain)" ]; then
        echo "== $repo: no changes"
        continue
    fi

    git add -A
    git -c user.name="$PUBLIC_NAME" -c user.email="$PUBLIC_EMAIL" commit -q -m "$MESSAGE"
    [ -n "$TAG" ] && git tag -a "$TAG" -m "$MESSAGE"
    echo "== $repo: committed${TAG:+ and tagged $TAG}"
done

echo
echo "Done. Review, then push:"
echo "  cd \"$PUBLIC_DIR/captain-claw-miyoo\" && git push${TAG:+ --follow-tags}"
echo "  cd \"$PUBLIC_DIR/openclaw-miyoo\"    && git push${TAG:+ --follow-tags}"
