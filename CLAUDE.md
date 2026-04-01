# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pm-guard is a Claude Code plugin that prevents Claude from using the wrong package manager (npm/yarn/pnpm/bun/deno). It works as a `PreToolUse` hook that intercepts `Bash` tool calls and blocks commands using disallowed package managers.

## Architecture

This is a Claude Code plugin distributed as a custom marketplace. The repo root is the marketplace; the plugin lives under `plugins/pm-guard/`:

- `.claude-plugin/marketplace.json` - Marketplace manifest (name, owner, plugin list)
- `plugins/pm-guard/.claude-plugin/plugin.json` - Plugin manifest (name, version, metadata)
- `plugins/pm-guard/hooks/hooks.json` - Hook registration: binds `check-pm.sh` to `PreToolUse` events on the `Bash` tool
- `plugins/pm-guard/hooks/check-pm.sh` - Core logic: a pure bash script that reads tool input JSON from stdin, extracts the command, detects the allowed package manager, and blocks disallowed ones

## How check-pm.sh Works

1. **Parses stdin JSON** to extract `tool_input.command` (using sed + awk, no jq dependency)
2. **Detects allowed PM** with priority: `PM_GUARD_ALLOWED` env var > `package.json` `packageManager` field > lockfile detection
3. **Strips quoted content** (single and double quotes) to avoid false positives on strings like `grep "npm" package.json`. Known trade-off: `bash -c "npm install"` won't be caught.
4. **Blocks disallowed PMs** using word-boundary regex (not preceded by `[a-zA-Z0-9_.-]`, not followed by `[a-zA-Z0-9_./-]`) to avoid false positives like `pnpm-lock.yaml`, `.npm/`, `npm-check`
5. **Outputs hook JSON** with one of three outcomes:
   - `deny` decision with reason (blocked PM detected)
   - `systemMessage` warning (PM could not be detected AND command contains a PM keyword)
   - Clean exit with no output (command allowed, or no PM detected and command has no PM keywords)

## Development

```bash
# Test the plugin locally
claude --plugin-dir ./plugins/pm-guard

# Run check-pm.sh directly with mock input
echo '{"tool_input":{"command":"npm install foo"}}' | PM_GUARD_ALLOWED=pnpm ./plugins/pm-guard/hooks/check-pm.sh

# Run BATS tests
./scripts/setup-tests.sh
./tests/test_helper/bats-core/bin/bats tests/check-pm.bats
```

No build step, no dependencies. The script must remain POSIX-ish bash (no jq, no node) to work in any environment. Tests use BATS (Bash Automated Testing System), downloaded on demand via `scripts/setup-tests.sh`.
