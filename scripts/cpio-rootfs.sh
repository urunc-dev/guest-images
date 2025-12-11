#!/usr/bin/env bash
# Build rootfs.cpio in the current directory: an initrd (a newc cpio archive)
# with the contents of a directory plus urunit 86913f1 at /urunit. bunny's own
# initrd is not reproducible, so the prebuild.sh of an initrd image calls this
# from the build context, with ARCH set, and the bunnyfile takes the result
# (rootfs: from: local, path: rootfs.cpio, type: initrd).
#
# Usage: ARCH=<amd64|arm64> cpio-rootfs.sh <directory>
#   <directory>  the files to put in the initrd, relative to the current
#                directory
#
# Every input is pinned by digest. Every file is owned by root, directories
# and executables get mode 755 and other files 644, every timestamp is 0 and
# inodes are renumbered, so the archive is reproducible. A change to this
# script rebuilds every image.
set -euo pipefail

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
	echo "Usage: ARCH=<amd64|arm64> $0 <directory>" >&2
	exit 1
fi
DIR=$1

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
# busybox 1.38.0, whose cpio can renumber inodes and ignore device numbers.
TOOLS=docker.io/library/busybox:1.38.0@sha256:a46257e06c82ad85242d0d38077d0a52d9896389ca60a1a59d3463db586e5fa4

docker buildx build --platform "linux/$ARCH" --output type=local,dest=. \
	-f - "$DIR" <<EOF
FROM $URUNIT AS urunit

FROM scratch AS tree
COPY . /
COPY --from=urunit /urunit /urunit

FROM $TOOLS AS mkcpio
RUN --mount=type=bind,from=tree,target=/tree --mount=type=tmpfs,target=/work \\
    cp -a /tree/. /work/ \\
 && cd /work \\
 && chmod -R u=rwX,go=rX . \\
 && find . -exec touch -h -d @0 {} + \\
 && find . | sort \\
  | cpio -o -H newc -R 0:0 --ignore-devno --renumber-inodes > /rootfs.cpio

FROM scratch
COPY --from=mkcpio /rootfs.cpio /
EOF
