# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pm-guard is a Claude Code plugin that prevents Claude from using the wrong package manager (npm/yarn/pnpm/bun/deno). It works as a `PreToolUse` hook that intercepts `Bash` tool calls and blocks commands using disallowed package managers.

## Architecture

This is a Claude Code plugin. The structure is minimal:

- `.claude-plugin/plugin.json` - Plugin manifest (name, version, metadata)
- `hooks/hooks.json` - Hook registration: binds `check-pm.sh` to `PreToolUse` events on the `Bash` tool
- `hooks/check-pm.sh` - Core logic: a pure bash script that reads tool input JSON from stdin, extracts the command, detects the allowed package manager, and blocks disallowed ones

## How check-pm.sh Works

1. **Parses stdin JSON** to extract `tool_input.command` (using sed + awk, no jq dependency)
2. **Detects allowed PM** with priority: `PM_GUARD_ALLOWED` env var > `package.json` `packageManager` field > lockfile detection
3. **Blocks disallowed PMs** using word-boundary regex to avoid false positives (e.g., `pnpm-lock.yaml` won't trigger a block). The boundary pattern at line 93: not preceded by `[a-zA-Z0-9_.-]`, not followed by `[a-zA-Z0-9_./-]`
4. **Outputs hook JSON** with one of three outcomes:
   - `deny` decision with reason (blocked PM detected)
   - `systemMessage` warning (PM could not be detected)
   - Clean exit with no output (command allowed)

## Development

```bash
# Test the plugin locally
claude --plugin-dir ./

# Run check-pm.sh directly with mock input
echo '{"tool_input":{"command":"npm install foo"}}' | PM_GUARD_ALLOWED=pnpm ./hooks/check-pm.sh
```

No build step, no dependencies. The script must remain POSIX-ish bash (no jq, no node) to work in any environment.
