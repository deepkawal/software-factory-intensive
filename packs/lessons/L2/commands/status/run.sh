#!/usr/bin/env bash
set -euo pipefail

echo "Feature-intake artifacts"
echo
echo "Plans:"
find docs/plans -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | sed 's/^/  /' || true
echo
echo "Architecture:"
find docs/architecture -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | sed 's/^/  /' || true
