#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/bump-version.sh [major|minor|patch]
# Bumps the version in plugin.json according to semver.

PLUGIN_JSON="$(cd "$(dirname "$0")/.." && pwd)/plugins/pm-guard/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "Error: plugin.json not found at $PLUGIN_JSON" >&2
  exit 1
fi

BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
  major|minor|patch) ;;
  *)
    echo "Usage: $0 [major|minor|patch]" >&2
    exit 1
    ;;
esac

# Extract current version
CURRENT=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PLUGIN_JSON")

if [[ -z "$CURRENT" ]]; then
  echo "Error: could not read version from $PLUGIN_JSON" >&2
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# Update plugin.json in-place
sed -i "s/\"version\": *\"${CURRENT}\"/\"version\": \"${NEW_VERSION}\"/" "$PLUGIN_JSON"

echo "${CURRENT} -> ${NEW_VERSION}"
