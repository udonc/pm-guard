#!/usr/bin/env bash

_common_setup() {
  load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load"
  load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load"

  HOOK_SCRIPT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)/plugins/pm-guard/hooks/check-pm.sh"
  TEST_TEMP_DIR="$(mktemp -d)"
  TEST_INPUT_FILE="$(mktemp)"
}

_common_teardown() {
  rm -rf "$TEST_TEMP_DIR"
  rm -f "$TEST_INPUT_FILE"
}

# run_hook [--pm PM] [--dir DIR] "command"
# Builds JSON and pipes it to check-pm.sh
run_hook() {
  local pm="" dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pm)  pm="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      *)     break ;;
    esac
  done
  local cmd="$1"
  # Escape for JSON: backslashes first, then double quotes
  local json_cmd
  json_cmd=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf '{"tool_input":{"command":"%s"}}' "$json_cmd" > "$TEST_INPUT_FILE"
  _run_script "$pm" "$dir"
}

# run_hook_raw [--pm PM] [--dir DIR] "raw_stdin"
# Passes raw stdin directly to check-pm.sh (for JSON edge cases)
run_hook_raw() {
  local pm="" dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pm)  pm="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      *)     break ;;
    esac
  done

  printf '%s' "$1" > "$TEST_INPUT_FILE"
  _run_script "$pm" "$dir"
}

# _run_script <pm> <dir>
# Internal: runs check-pm.sh with input from TEST_INPUT_FILE
_run_script() {
  local pm="$1" dir="$2"

  if [[ -n "$pm" ]]; then
    export PM_GUARD_ALLOWED="$pm"
  else
    unset PM_GUARD_ALLOWED 2>/dev/null || true
  fi

  if [[ -n "$dir" ]]; then
    run bash -c "cd '$dir' && bash '$HOOK_SCRIPT' < '$TEST_INPUT_FILE'"
  else
    run bash "$HOOK_SCRIPT" < "$TEST_INPUT_FILE"
  fi
}

assert_allowed() {
  assert_success
  assert_output ""
}

assert_denied() {
  local allowed_pm="$1"
  local blocked_pm="$2"
  assert_success
  assert_output --partial '"permissionDecision":"deny"'
  assert_output --partial "This project uses ${allowed_pm}"
  assert_output --partial "instead of ${blocked_pm}"
}

assert_warning() {
  assert_success
  assert_output --partial '"systemMessage"'
  assert_output --partial "Could not detect"
}

create_lockfile() {
  touch "${2:-$TEST_TEMP_DIR}/$1"
}

create_package_json() {
  local pm_value="$1"
  local dir="${2:-$TEST_TEMP_DIR}"
  printf '{"name":"test","packageManager":"%s"}\n' "$pm_value" > "$dir/package.json"
}
