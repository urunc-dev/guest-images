#!/usr/bin/env bash
# Build readfile from readfile.c in the build context (readfile/src, the
# working directory CI runs this from), where the bunnyfile picks it up
# together with file.txt.
set -euo pipefail

bash "$(git rev-parse --show-toplevel)/scripts/cc-static.sh" readfile.c readfile
# The bunnyfile copies file.txt with its mode, which otherwise follows the
# umask of the checkout.
chmod 0644 file.txt
