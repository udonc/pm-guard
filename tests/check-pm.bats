#!/usr/bin/env bats

setup() {
  load 'test_helper/common'
  _common_setup
}

teardown() {
  _common_teardown
}

# =============================================================================
# A: JSON Parsing & Command Extraction
# =============================================================================

@test "json: extracts simple command" {
  run_hook --pm pnpm "pnpm install"
  assert_allowed
}

@test "json: handles escaped newlines in command" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"echo hello\\npnpm install"}}'
  assert_allowed
}

@test "json: handles escaped tabs in command" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"echo\\tpnpm install"}}'
  assert_allowed
}

@test "json: handles escaped quotes in command" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"echo \\\"pnpm install\\\""}}'
  assert_allowed
}

@test "json: handles escaped backslashes" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"echo \\\\pnpm"}}'
  assert_allowed
}

@test "json: handles extra whitespace in JSON" {
  run_hook_raw --pm pnpm '{"tool_input":{ "command" : "pnpm install" }}'
  assert_allowed
}

@test "json: handles empty command value" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":""}}'
  assert_allowed
}

@test "json: handles missing command field" {
  run_hook_raw --pm pnpm '{"tool_input":{}}'
  assert_allowed
}

@test "json: handles missing tool_input" {
  run_hook_raw --pm pnpm '{}'
  assert_allowed
}

@test "json: handles multiline command with escaped newlines blocking disallowed PM" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"cd /tmp\nnpm install"}}'
  assert_denied "pnpm" "npm"
}

# =============================================================================
# B: PM Detection Priority 1 -- PM_GUARD_ALLOWED env var
# =============================================================================

@test "env: PM_GUARD_ALLOWED=pnpm blocks npm" {
  run_hook --pm pnpm "npm install"
  assert_denied "pnpm" "npm"
}

@test "env: PM_GUARD_ALLOWED=npm allows npm" {
  run_hook --pm npm "npm install"
  assert_allowed
}

@test "env: PM_GUARD_ALLOWED overrides package.json" {
  create_package_json "yarn@4.0.0"
  run_hook --pm pnpm --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "env: PM_GUARD_ALLOWED overrides lockfile" {
  create_lockfile "yarn.lock"
  run_hook --pm pnpm --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "env: PM_GUARD_ALLOWED=bun allows bun and bunx" {
  run_hook --pm bun "bun install"
  assert_allowed
  run_hook --pm bun "bunx create-next-app"
  assert_allowed
}

@test "env: PM_GUARD_ALLOWED=deno allows deno" {
  run_hook --pm deno "deno install"
  assert_allowed
}

# =============================================================================
# C: PM Detection Priority 2 -- package.json packageManager
# =============================================================================

@test "package.json: detects pnpm from packageManager field" {
  create_package_json "pnpm@9.0.0"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "package.json: strips version suffix" {
  create_package_json "pnpm@9.15.4"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "package.json: detects yarn" {
  create_package_json "yarn@4.0.0"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "yarn" "npm"
}

@test "package.json: detects npm" {
  create_package_json "npm@10.0.0"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_allowed
}

@test "package.json: detects bun" {
  create_package_json "bun@1.0.0"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "bun" "npm"
}

@test "package.json: packageManager without version" {
  create_package_json "pnpm"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "package.json: ignored when PM_GUARD_ALLOWED is set" {
  create_package_json "yarn@4.0.0"
  run_hook --pm npm --dir "$TEST_TEMP_DIR" "npm install"
  assert_allowed
}

@test "package.json: takes priority over lockfile" {
  create_package_json "pnpm@9.0.0"
  create_lockfile "yarn.lock"
  run_hook --dir "$TEST_TEMP_DIR" "yarn install"
  assert_denied "pnpm" "yarn"
}

# =============================================================================
# D: PM Detection Priority 3 -- Lockfile Detection
# =============================================================================

@test "lockfile: pnpm-lock.yaml detects pnpm" {
  create_lockfile "pnpm-lock.yaml"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "lockfile: yarn.lock detects yarn" {
  create_lockfile "yarn.lock"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "yarn" "npm"
}

@test "lockfile: package-lock.json detects npm" {
  create_lockfile "package-lock.json"
  run_hook --dir "$TEST_TEMP_DIR" "pnpm install"
  assert_denied "npm" "pnpm"
}

@test "lockfile: bun.lock detects bun" {
  create_lockfile "bun.lock"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "bun" "npm"
}

@test "lockfile: bun.lockb detects bun" {
  create_lockfile "bun.lockb"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "bun" "npm"
}

@test "lockfile: deno.lock detects deno" {
  create_lockfile "deno.lock"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "deno" "npm"
}

@test "lockfile: pnpm-lock.yaml takes priority over yarn.lock" {
  create_lockfile "pnpm-lock.yaml"
  create_lockfile "yarn.lock"
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_denied "pnpm" "npm"
}

@test "lockfile: yarn.lock takes priority over package-lock.json" {
  create_lockfile "yarn.lock"
  create_lockfile "package-lock.json"
  run_hook --dir "$TEST_TEMP_DIR" "pnpm install"
  assert_denied "yarn" "pnpm"
}

# =============================================================================
# E: No PM Detected -- systemMessage Warning
# =============================================================================

@test "no-pm: warns when no detection method succeeds and command uses PM" {
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_warning
}

@test "no-pm: command is still allowed (exit 0)" {
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_success
}

@test "no-pm: warning message contains guidance" {
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_output --partial "PM_GUARD_ALLOWED"
  assert_output --partial "packageManager"
  assert_output --partial "lockfile"
}

@test "no-pm: no warning for non-PM commands" {
  run_hook --dir "$TEST_TEMP_DIR" "ls -la"
  assert_allowed
}

@test "no-pm: no warning for git commands" {
  run_hook --dir "$TEST_TEMP_DIR" "git status"
  assert_allowed
}

@test "no-pm: no warning for commands referencing PM in filenames" {
  run_hook --dir "$TEST_TEMP_DIR" "cat pnpm-lock.yaml"
  assert_allowed
}

@test "no-pm: no warning for double-quoted PM string" {
  run_hook --dir "$TEST_TEMP_DIR" 'grep "npm" package.json'
  assert_allowed
}

@test "no-pm: no warning for single-quoted PM string" {
  run_hook --dir "$TEST_TEMP_DIR" "echo 'pnpm install'"
  assert_allowed
}

# =============================================================================
# F: Allowed Commands Mapping
# =============================================================================

@test "allowed: npm allows npm and npx" {
  run_hook --pm npm "npm install"
  assert_allowed
  run_hook --pm npm "npx create-react-app"
  assert_allowed
}

@test "allowed: npm blocks yarn pnpm pnpx bun bunx deno" {
  run_hook --pm npm "yarn install"
  assert_denied "npm" "yarn"
  run_hook --pm npm "pnpm install"
  assert_denied "npm" "pnpm"
  run_hook --pm npm "bun install"
  assert_denied "npm" "bun"
  run_hook --pm npm "deno install"
  assert_denied "npm" "deno"
}

@test "allowed: yarn allows yarn" {
  run_hook --pm yarn "yarn install"
  assert_allowed
}

@test "allowed: yarn blocks npm npx pnpm pnpx bun bunx deno" {
  run_hook --pm yarn "npm install"
  assert_denied "yarn" "npm"
  run_hook --pm yarn "npx create-react-app"
  assert_denied "yarn" "npx"
  run_hook --pm yarn "pnpm install"
  assert_denied "yarn" "pnpm"
  run_hook --pm yarn "bun install"
  assert_denied "yarn" "bun"
}

@test "allowed: pnpm allows pnpm and pnpx" {
  run_hook --pm pnpm "pnpm install"
  assert_allowed
  run_hook --pm pnpm "pnpx create-react-app"
  assert_allowed
}

@test "allowed: pnpm blocks npm npx yarn bun bunx deno" {
  run_hook --pm pnpm "npm install"
  assert_denied "pnpm" "npm"
  run_hook --pm pnpm "npx create-react-app"
  assert_denied "pnpm" "npx"
  run_hook --pm pnpm "yarn install"
  assert_denied "pnpm" "yarn"
  run_hook --pm pnpm "bun install"
  assert_denied "pnpm" "bun"
}

@test "allowed: bun allows bun and bunx" {
  run_hook --pm bun "bun install"
  assert_allowed
  run_hook --pm bun "bunx create-next-app"
  assert_allowed
}

@test "allowed: bun blocks npm npx yarn pnpm pnpx deno" {
  run_hook --pm bun "npm install"
  assert_denied "bun" "npm"
  run_hook --pm bun "yarn install"
  assert_denied "bun" "yarn"
  run_hook --pm bun "pnpm install"
  assert_denied "bun" "pnpm"
  run_hook --pm bun "deno install"
  assert_denied "bun" "deno"
}

@test "allowed: deno allows deno" {
  run_hook --pm deno "deno install"
  assert_allowed
}

@test "allowed: deno blocks npm npx yarn pnpm pnpx bun bunx" {
  run_hook --pm deno "npm install"
  assert_denied "deno" "npm"
  run_hook --pm deno "yarn install"
  assert_denied "deno" "yarn"
  run_hook --pm deno "pnpm install"
  assert_denied "deno" "pnpm"
  run_hook --pm deno "bun install"
  assert_denied "deno" "bun"
}

@test "allowed: unknown PM exits cleanly" {
  run_hook --pm pip "npm install"
  assert_allowed
}

# =============================================================================
# G: Word Boundary Regex -- False Positive Prevention
# =============================================================================

@test "boundary: does not block pnpm-lock.yaml in cat command" {
  run_hook --pm npm "cat pnpm-lock.yaml"
  assert_allowed
}

@test "boundary: does not block .npm/ directory reference" {
  run_hook --pm pnpm "ls .npm/cache"
  assert_allowed
}

@test "boundary: does not block npm in .npmrc" {
  run_hook --pm pnpm "cat .npmrc"
  assert_allowed
}

@test "boundary: does not block npm in URL-like string" {
  run_hook --pm pnpm "curl https://registry.npmjs.org/"
  assert_allowed
}

@test "boundary: does not block yarn in .yarnrc.yml" {
  run_hook --pm pnpm "cat .yarnrc.yml"
  assert_allowed
}

@test "boundary: does not block npm_ prefix in env var" {
  run_hook --pm pnpm 'echo $npm_config_registry'
  assert_allowed
}

@test "boundary: does not block pnpm followed by dash" {
  run_hook --pm npm "git add pnpm-lock.yaml"
  assert_allowed
}

@test "boundary: does not block npm followed by dash in package name" {
  run_hook --pm pnpm "ls npm-check"
  assert_allowed
}

@test "boundary: blocks npm at start of command" {
  run_hook --pm pnpm "npm install"
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm after semicolon" {
  run_hook --pm pnpm "echo hello; npm install"
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm after pipe" {
  run_hook --pm pnpm "echo foo | npm install"
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm after && operator" {
  run_hook --pm pnpm "cd /tmp && npm install"
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm at end of command" {
  run_hook --pm pnpm "which npm"
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm in subshell" {
  run_hook --pm pnpm '$(npm list)'
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm after newline in multiline command" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"ls\nnpm install"}}'
  assert_denied "pnpm" "npm"
}

@test "boundary: blocks npm after backtick" {
  run_hook --pm pnpm '`npm list`'
  assert_denied "pnpm" "npm"
}

# =============================================================================
# H: Deny Output Format
# =============================================================================

@test "output: deny has correct JSON structure" {
  run_hook --pm pnpm "npm install"
  assert_output --partial '"hookSpecificOutput"'
  assert_output --partial '"hookEventName":"PreToolUse"'
  assert_output --partial '"permissionDecision":"deny"'
  assert_output --partial '"permissionDecisionReason"'
}

@test "output: deny message names the allowed PM" {
  run_hook --pm pnpm "npm install"
  assert_output --partial "This project uses pnpm"
}

@test "output: deny message names the blocked PM" {
  run_hook --pm pnpm "npm install"
  assert_output --partial "instead of npm"
}

@test "output: deny exit code is 0" {
  run_hook --pm pnpm "npm install"
  assert_success
}

# =============================================================================
# I: Edge Cases & Integration
# =============================================================================

@test "edge: empty stdin" {
  run_hook_raw --pm pnpm ""
  assert_success
}

@test "edge: non-PM command is always allowed" {
  run_hook --pm pnpm "ls -la"
  assert_allowed
}

@test "edge: complex multi-command with only allowed PM" {
  run_hook --pm pnpm "cd /app && pnpm install && pnpm build"
  assert_allowed
}

@test "edge: complex multi-command with mixed PMs" {
  run_hook --pm pnpm "pnpm install && npm publish"
  assert_denied "pnpm" "npm"
}

@test "edge: command with PM in quoted string is allowed" {
  run_hook --pm pnpm 'echo "use npm to install"'
  assert_allowed
}

@test "edge: heredoc-style command blocks disallowed PM" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"cat <<EOF\nnpm install\nEOF"}}'
  assert_denied "pnpm" "npm"
}

@test "edge: PM_GUARD_ALLOWED empty string treated as unset" {
  create_lockfile "pnpm-lock.yaml"
  run_hook_raw --dir "$TEST_TEMP_DIR" '{"tool_input":{"command":"npm install"}}'
  assert_denied "pnpm" "npm"
}

# =============================================================================
# J: Quote-Aware Detection -- False Positive Prevention
# =============================================================================

@test "quotes: PM in double-quoted echo argument is allowed" {
  run_hook --pm pnpm 'echo "npm is a package manager"'
  assert_allowed
}

@test "quotes: PM in single-quoted echo argument is allowed" {
  run_hook --pm pnpm "echo 'npm install'"
  assert_allowed
}

@test "quotes: PM outside quotes after semicolon is blocked" {
  run_hook --pm pnpm 'echo "hello"; npm install'
  assert_denied "pnpm" "npm"
}

@test "quotes: PM in printf double-quoted argument is allowed" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"printf \"use npm\\n\""}}'
  assert_allowed
}

@test "quotes: bash -c with PM in quotes is allowed (trade-off)" {
  run_hook --pm pnpm 'bash -c "npm install"'
  assert_allowed
}

@test "quotes: mixed -- quoted PM allowed, unquoted PM blocked" {
  run_hook --pm pnpm 'echo "npm" && yarn install'
  assert_denied "pnpm" "yarn"
}

@test "quotes: PM at start still blocked without quotes" {
  run_hook --pm pnpm "npm install"
  assert_denied "pnpm" "npm"
}

@test "quotes: multiline -- quoted PM on first line, real PM on second" {
  run_hook_raw --pm pnpm '{"tool_input":{"command":"echo \"npm is cool\"\nnpm install"}}'
  assert_denied "pnpm" "npm"
}

@test "edge: script exits 0 on every code path" {
  # Allowed command
  run_hook --pm pnpm "pnpm install"
  assert_success
  # Denied command
  run_hook --pm pnpm "npm install"
  assert_success
  # No PM detected
  run_hook --dir "$TEST_TEMP_DIR" "npm install"
  assert_success
  # Empty command
  run_hook_raw --pm pnpm '{"tool_input":{"command":""}}'
  assert_success
}
