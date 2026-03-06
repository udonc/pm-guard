# pm-guard — Never accidentally `npm install` in a pnpm project again

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that prevents Claude from using the wrong package manager.

## What It Does

- Guards npm, yarn, pnpm, bun, and deno (including `npx`, `pnpx`, `bunx`)
- Auto-detects the project's package manager from env var, `package.json`, or lockfiles
- Blocks disallowed commands before execution via `PreToolUse` hook
- Zero dependencies — pure bash, no jq or node required

## Quick Start

1. Add the marketplace:

   ```
   /plugin marketplace add udonc/pm-guard
   ```

2. Install the plugin:

   ```
   /plugin install pm-guard@pm-guard
   ```

3. That's it. pm-guard auto-detects your package manager from lockfiles or `package.json` — no configuration needed.

If Claude tries to use the wrong package manager, the command is blocked:

> This project uses pnpm. Use pnpm commands instead of npm.

## Configuration

The allowed package manager is detected with the following priority:

### 1. `PM_GUARD_ALLOWED` environment variable (highest priority)

```bash
PM_GUARD_ALLOWED=pnpm claude
```

### 2. `packageManager` field in `package.json`

```json
{
  "packageManager": "pnpm@9.15.4"
}
```

The version suffix is ignored — only the package manager name is used.

### 3. Lockfile detection (lowest priority)

| Lockfile | Detected PM |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `package-lock.json` | npm |
| `bun.lock` / `bun.lockb` | bun |
| `deno.lock` | deno |

## How It Works

pm-guard registers a `PreToolUse` hook on the `Bash` tool. When Claude attempts to run a shell command, the hook:

1. Extracts the command from the tool input JSON
2. Determines the allowed package manager (see [Configuration](#configuration))
3. Checks the command for disallowed package manager invocations using word-boundary-aware regex (avoids false positives on strings like `pnpm-lock.yaml` or `.npm/`)
4. Blocks the command with a `deny` decision if a violation is found, or allows it to proceed

If the package manager cannot be detected, a warning is emitted and the command is allowed.

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| "Could not detect the project's package manager" warning | No lockfile, no `packageManager` field, no `PM_GUARD_ALLOWED` env var | Add a lockfile, set `packageManager` in `package.json`, or set `PM_GUARD_ALLOWED` |
| Correct command is being blocked | Wrong PM detected (e.g., stale lockfile from another PM) | Remove the stale lockfile or set `PM_GUARD_ALLOWED` to override |
| Plugin not working | Not installed or not loaded | Run `/plugin list` to verify pm-guard is installed |

## Development

```bash
# Test the plugin locally
claude --plugin-dir ./plugins/pm-guard

# Run check-pm.sh directly with mock input
echo '{"tool_input":{"command":"npm install foo"}}' | PM_GUARD_ALLOWED=pnpm ./plugins/pm-guard/hooks/check-pm.sh
```

No build step. The script must remain POSIX-ish bash with no external dependencies.

## License

MIT
