#!/usr/bin/env bash
# Build rootfs.ext4, the block rootfs of this image: busybox 1.38.0
# with urunit, in the build context (this image directory, the working
# directory CI runs this from), where the bunnyfile picks it up.
set -euo pipefail

case "$ARCH" in
amd64)
	# The linux/amd64 entry of busybox:1.38.0.
	IMAGE=docker.io/library/busybox:1.38.0@sha256:f97baa533a26513c453a362be331a43eb60214302f449c16571b23cea141dce4
	;;
arm64)
	# The linux/arm64 entry of busybox:1.38.0.
	IMAGE=docker.io/library/busybox:1.38.0@sha256:365a051f12e05767b598e643676f14a450fb678a75ccf2beb0052c95d5c73b83
	;;
*)
	echo "Unsupported ARCH '$ARCH'" >&2
	exit 1
	;;
esac

exec bash "$(git rev-parse --show-toplevel)/scripts/ext4-rootfs.sh" "$IMAGE" 32M
