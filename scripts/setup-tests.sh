#!/usr/bin/env bash
set -euo pipefail

BATS_DIR="$(cd "$(dirname "$0")/.." && pwd)/tests/test_helper"

clone_if_missing() {
  local name="$1" url="$2"
  if [ ! -d "$BATS_DIR/$name" ]; then
    echo "Downloading $name..."
    git clone --depth 1 "$url" "$BATS_DIR/$name"
  else
    echo "$name already exists, skipping."
  fi
}

clone_if_missing bats-core    https://github.com/bats-core/bats-core.git
clone_if_missing bats-support https://github.com/bats-core/bats-support.git
clone_if_missing bats-assert  https://github.com/bats-core/bats-assert.git

echo "Done. Run tests with: ./tests/test_helper/bats-core/bin/bats tests/*.bats"
