#!/usr/bin/env bash
# Build app from app.c in the build context (hello-exec-env/src, the working
# directory CI runs this from), where the bunnyfile picks it up.
set -euo pipefail

bash "$(git rev-parse --show-toplevel)/scripts/cc-static.sh" app.c app
