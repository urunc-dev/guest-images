#!/usr/bin/env bash
# Build rootfs.cpio, the initrd of this image, in the build context
# (hello-exec-env/src, the working directory CI runs this from), where the
# bunnyfile picks it up: app, built from app.c, and the empty working
# directory /test_dir, with urunit. bunny does not add the working directory
# to a prebuilt rootfs, so it has to be in the initrd.
set -euo pipefail

scripts="$(git rev-parse --show-toplevel)/scripts"
rm -rf rootfs
mkdir -p rootfs/test_dir
bash "$scripts/cc-static.sh" app.c rootfs/app
bash "$scripts/cpio-rootfs.sh" rootfs
