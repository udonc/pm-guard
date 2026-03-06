#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin
input=$(cat)

# Extract the command string from tool_input.command
# 1. Strip everything before "command":"
# 2. Parse JSON string value (handle escape sequences, stop at closing quote)
command=$(printf '%s' "$input" | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//' | awk '{
  s = $0
  result = ""
  i = 1
  while (i <= length(s)) {
    c = substr(s, i, 1)
    if (c == "\\") {
      i++
      nc = substr(s, i, 1)
      if (nc == "n") result = result "\n"
      else if (nc == "t") result = result "\t"
      else result = result nc
    } else if (c == "\"") {
      break
    } else {
      result = result c
    }
    i++
  }
  printf "%s", result
}')

# No command found → allow
if [ -z "$command" ]; then
  exit 0
fi

# --- Determine the allowed package manager ---
allowed_pm=""

# Priority 1: PM_GUARD_ALLOWED environment variable
if [ -n "${PM_GUARD_ALLOWED:-}" ]; then
  allowed_pm="$PM_GUARD_ALLOWED"
fi

# Priority 2: package.json "packageManager" field
if [ -z "$allowed_pm" ] && [ -f package.json ]; then
  allowed_pm=$(sed -n 's/.*"packageManager"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json | head -1 | sed 's/@.*//')
fi

# Priority 3: Lockfile detection
if [ -z "$allowed_pm" ]; then
  if [ -f pnpm-lock.yaml ]; then allowed_pm="pnpm"
  elif [ -f yarn.lock ]; then allowed_pm="yarn"
  elif [ -f package-lock.json ]; then allowed_pm="npm"
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then allowed_pm="bun"
  elif [ -f deno.lock ]; then allowed_pm="deno"
  fi
fi

# Cannot determine PM → warn and allow
if [ -z "$allowed_pm" ]; then
  cat <<'EOF'
{"systemMessage":"pm-guard: Could not detect the project's package manager. Set PM_GUARD_ALLOWED env var, add packageManager to package.json, or ensure a lockfile exists."}
EOF
  exit 0
fi

# --- Build blocked command list ---
case "$allowed_pm" in
  npm)  allowed_cmds="npm npx" ;;
  yarn) allowed_cmds="yarn" ;;
  pnpm) allowed_cmds="pnpm pnpx" ;;
  bun)  allowed_cmds="bun bunx" ;;
  deno) allowed_cmds="deno" ;;
  *)    exit 0 ;;
esac

all_cmds="npm npx yarn pnpm pnpx bun bunx deno"

blocked=""
for cmd in $all_cmds; do
  case " $allowed_cmds " in
    *" $cmd "*) ;;
    *) blocked="${blocked:+$blocked|}$cmd" ;;
  esac
done

[ -z "$blocked" ] && exit 0

# --- Check command for blocked PM usage ---
# Word boundaries: not preceded by [a-zA-Z0-9_.-], not followed by [a-zA-Z0-9_./-]
# Avoids false positives like "pnpm-lock.yaml", ".npm/", "npm-check"
if printf '%s' "$command" | grep -qE "(^|[^a-zA-Z0-9_.-])(${blocked})([^a-zA-Z0-9_./-]|$)"; then
  matched=$(printf '%s' "$command" | grep -oE "(^|[^a-zA-Z0-9_.-])(${blocked})([^a-zA-Z0-9_./-]|$)" | head -1 | sed 's/^[^a-zA-Z]*//;s/[^a-zA-Z]*$//')
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"This project uses ${allowed_pm}. Use ${allowed_pm} commands instead of ${matched}."}}
EOF
  exit 0
fi

exit 0
