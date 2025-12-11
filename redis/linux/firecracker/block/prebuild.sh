#!/usr/bin/env bash
# Build rootfs.ext4, the block rootfs of this image: redis 8.8.4 (Alpine)
# with urunit, in the build context (this image directory, the working
# directory CI runs this from), where the bunnyfile picks it up.
set -euo pipefail

case "$ARCH" in
amd64)
	# The linux/amd64 entry of redis:8.8.4-alpine.
	IMAGE=docker.io/library/redis:8.8.4-alpine@sha256:b85e284e14f616937c8e94a5d0374a6cfa6eb4bc5d6ab4ce59e38eca2fcec476
	;;
arm64)
	# The linux/arm64 entry of redis:8.8.4-alpine.
	IMAGE=docker.io/library/redis:8.8.4-alpine@sha256:03653329c825af4e7e683e48e38f09d6130d95d65f3dd9e4bb2105561f1684c9
	;;
*)
	echo "Unsupported ARCH '$ARCH'" >&2
	exit 1
	;;
esac

exec bash "$(git rev-parse --show-toplevel)/scripts/ext4-rootfs.sh" "$IMAGE" 160M
