#!/usr/bin/env bash
# Build rootfs.cpio, the initrd of this image, in the build context
# (hello-world/src, the working directory CI runs this from), where the
# bunnyfile picks it up: clis, built from clis.c, with urunit.
set -euo pipefail

scripts="$(git rev-parse --show-toplevel)/scripts"
rm -rf rootfs
mkdir rootfs
bash "$scripts/cc-static.sh" clis.c rootfs/clis
bash "$scripts/cpio-rootfs.sh" rootfs
