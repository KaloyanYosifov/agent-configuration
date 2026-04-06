#!/usr/bin/env bash
set -euo pipefail

# Read input JSON
input=""
while IFS= read -r line || [[ -n "$line" ]]; do
  input+="$line"
done
[[ -z "$input" ]] && exit 0

# Require jq
command -v jq >/dev/null 2>&1 || exit 0

# Get current workspace directory (passed by Cursor/Claude or fall back to $PWD)
# Canonicalize with realpath semantics so prefix checks match resolved targets.
_workspace_raw="${WORKSPACE:-${PWD}}"
if command -v python3 >/dev/null 2>&1; then
  workspace=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$_workspace_raw")
else
  workspace=$(cd "$_workspace_raw" && pwd -P)
fi

# True if resolved path is under workspace or /tmp (handles .., symlinks, macOS /private/tmp).
is_safe_path() {
  local path="$1"
  local resolved

  [[ -z "$path" ]] && return 1

  if command -v python3 >/dev/null 2>&1; then
    resolved=$(PYTHONDONTWRITEBYTECODE=1 python3 -c '
import os, sys
ws, p = sys.argv[1], sys.argv[2]
if p.startswith("-"):
    sys.exit(1)
full = os.path.join(ws, p) if not os.path.isabs(p) else p
print(os.path.realpath(full))
' "$workspace" "$path" 2>/dev/null) || return 1
  elif command -v realpath >/dev/null 2>&1 && realpath -m / >/dev/null 2>&1; then
    if [[ "$path" == /* ]]; then
      resolved=$(realpath -m "$path" 2>/dev/null) || return 1
    else
      resolved=$(realpath -m "$workspace/$path" 2>/dev/null) || return 1
    fi
  else
    resolved=$(cd "$workspace" 2>/dev/null && cd -- "$path" 2>/dev/null && pwd -P) || return 1
  fi

  [[ -z "$resolved" ]] && return 1

  if [[ "$resolved" == "$workspace" || "$resolved" == "$workspace/"* ]]; then
    return 0
  fi
  if [[ "$resolved" == /tmp || "$resolved" == /tmp/* || "$resolved" == /private/tmp || "$resolved" == /private/tmp/* ]]; then
    return 0
  fi
  return 1
}

# --- Path-based check (Cursor Delete tool / beforeFileModification / Claude Write|Edit) ---
# These payloads carry a file path rather than a shell command.
file_path=$(echo "$input" | jq -r '.path // .file_path // .tool_input.path // .tool_input.file_path // ""')
if [[ -n "$file_path" ]]; then
  if ! is_safe_path "$file_path"; then
    echo "Blocked: file operation targets path outside workspace: '$file_path'" >&2
    exit 2
  fi
  # Path is safe — nothing more to check for non-shell operations.
  if [[ "${BASH_SOURCE[0]}" == *".cursor"* ]] || [[ "$0" == *".cursor"* ]]; then
    echo '{"continue": true}'
  fi
  exit 0
fi

# --- Shell command check (beforeShellExecution / Claude Bash tool) ---
cmd=$(echo "$input" | jq -r '.command // .tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Block dangerous patterns EXCEPT controlled rm -rf
if echo "$cmd" | grep -qiE "(git reset --hard|git push.*--force|DROP TABLE|DROP DATABASE|curl.*\\|.*sh|wget.*\\|.*bash|mkfs|dd if=/dev/|:(){ :|:& };:|chmod -R 777)"; then
  echo "Blocked: '$cmd' matches dangerous pattern." >&2
  exit 2
fi

# Special handling for rm -rf / rm -r
if echo "$cmd" | grep -qE '\brm\s+(-r|-f|-rf|--recursive|--force|-R)\b'; then
  # Extract all paths after rm flags
  paths=$(echo "$cmd" | sed -E 's/.*rm\s+(-[a-zA-Z]*[rfR][a-zA-Z]*|-r|-f|--recursive|--force)\s+//' | tr ' ' '\n')

  for p in $paths; do
    # Skip flags and empty
    [[ "$p" =~ ^- ]] && continue
    [[ -z "$p" ]] && continue

    # Block if any path is unsafe
    if ! is_safe_path "$p"; then
      echo "Blocked: rm command targets unsafe path '$p'. Only allowed inside workspace or /tmp." >&2
      exit 2
    fi
  done
fi

# Allow the command
if [[ "${BASH_SOURCE[0]}" == *".cursor"* ]] || [[ "$0" == *".cursor"* ]]; then
  echo '{"continue": true}'
fi

exit 0
