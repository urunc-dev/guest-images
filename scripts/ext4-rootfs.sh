#!/usr/bin/env bash
# Build rootfs.ext4 in the current directory: an ext4 filesystem with the
# files of an image plus urunit 86913f1 at /urunit, for use as a block rootfs.
# bunny cannot build a block rootfs from an image yet, so the prebuild.sh of
# a block image calls this from the build context, with ARCH set.
#
# Usage: ARCH=<amd64|arm64> ext4-rootfs.sh <image> <size>
#   <image>  the rootfs image, pinned by the digest of its ARCH entry
#   <size>   the size of the filesystem, as mke2fs takes it (e.g. 96M)
#
# Every input is pinned by digest, and mke2fs runs with a fixed UUID and
# directory hash seed and SOURCE_DATE_EPOCH=0, so the file is reproducible.
# A change to this script rebuilds every image.
set -euo pipefail

if [ $# -ne 2 ]; then
	echo "Usage: ARCH=<amd64|arm64> $0 <image> <size>" >&2
	exit 1
fi
IMAGE=$1
SIZE=$2
if [[ "$IMAGE" != *@sha256:* ]]; then
	echo "Pin the image by digest: $IMAGE" >&2
	exit 1
fi

case "${ARCH:-}" in
amd64)
	# The linux/amd64 entry of urunit 86913f1.
	URUNIT=harbor.nbfc.io/nubificus/urunit:amd64-86913f1@sha256:aaf7e4cd333b9793e6dfa578b471e0ff45bb633e87491449f2ec5692d0cb8654
	;;
arm64)
	# The linux/arm64 entry of urunit 86913f1.
	URUNIT=harbor.nbfc.io/nubificus/urunit:arm64-86913f1@sha256:8c08675051b53cee325dee1007a464988097cb17d004bdad1f03b388254c41e2
	;;
*)
	echo "Unsupported ARCH '${ARCH:-}'" >&2
	exit 1
	;;
esac
# mke2fs 1.47.2, which sets every timestamp to SOURCE_DATE_EPOCH. Earlier
# versions copy each file's change time, which cannot be fixed beforehand.
TOOLS=docker.io/library/ubuntu:26.04@sha256:065aa8626841f16057b78b027b464cd59c4fac36c204c72dcbf48d66f5fa8a96
# Any value works, as long as it stays the same between builds.
UUID=6b2f3c7e-5f2a-4c1e-9a7d-2d0b8e4f1a90

docker buildx build --platform "linux/$ARCH" --output type=local,dest=. - <<EOF
FROM $URUNIT AS urunit

FROM $IMAGE AS rootfs
COPY --from=urunit /urunit /urunit

FROM $TOOLS AS mkfs
RUN --mount=type=bind,from=rootfs,target=/rootfs \\
    SOURCE_DATE_EPOCH=0 mke2fs -q -t ext4 -d /rootfs -L rootfs \\
      -U $UUID -E hash_seed=$UUID,root_owner=0:0 /rootfs.ext4 $SIZE

FROM scratch
COPY --from=mkfs /rootfs.ext4 /
EOF
