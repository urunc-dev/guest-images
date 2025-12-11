#!/usr/bin/env bash
# Compile a C program into a static binary for the native architecture. The
# prebuild.sh of images that run small test programs calls this from the
# build context.
#
# Usage: cc-static.sh <source.c> <output>
#   Both paths are relative to the current directory.
#
# The compiler image is pinned by digest and the binary has no debug info, so
# it is reproducible. A change to this script rebuilds every image.
set -euo pipefail

if [ $# -ne 2 ]; then
	echo "Usage: $0 <source.c> <output>" >&2
	exit 1
fi

# The same compiler chttp uses.
GCC_IMAGE=docker.io/library/gcc:15.2.0@sha256:3ae15afe768b06d0c0fe088d822ba5f8045c26630bdacc8d8e7713cf5d8e7289

docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/src" -w /src "$GCC_IMAGE" \
	gcc -O2 -Wall -Werror -static -o "$2" "$1"
# The mode would otherwise follow the umask of whoever builds it.
chmod 0755 "$2"
