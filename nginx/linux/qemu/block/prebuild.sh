#!/usr/bin/env bash
# Build rootfs.ext4, the block rootfs of this image: nginx 1.31.8 (Alpine)
# with urunit, in the build context (this image directory, the working
# directory CI runs this from), where the bunnyfile picks it up.
set -euo pipefail

case "$ARCH" in
amd64)
	# The linux/amd64 entry of nginx:1.31.8-alpine.
	IMAGE=docker.io/library/nginx:1.31.8-alpine@sha256:697b0b156c70b91130853fd0675c6be36665939d5f93dce2686be04b4c3f98a8
	;;
arm64)
	# The linux/arm64 entry of nginx:1.31.8-alpine.
	IMAGE=docker.io/library/nginx:1.31.8-alpine@sha256:5e3f1baf6e6505e8bc2b7ba50c790f94bb189b5e96c0ab2298fc745081c519a3
	;;
*)
	echo "Unsupported ARCH '$ARCH'" >&2
	exit 1
	;;
esac

exec bash "$(git rev-parse --show-toplevel)/scripts/ext4-rootfs.sh" "$IMAGE" 96M
