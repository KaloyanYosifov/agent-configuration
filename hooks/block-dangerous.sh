#!/usr/bin/env bash
set -euo pipefail

# Read input JSON
input=""
while IFS= read -r line || [[ -n "$line" ]]; do
  input+="$line"
done
[[ -z "$input" ]] && exit 0

# Extract command
if command -v jq >/dev/null 2>&1; then
  cmd=$(echo "$input" | jq -r '.command // .tool_input.command // ""')
else
  exit 0
fi
[[ -z "$cmd" ]] && exit 0

# Get current workspace directory (passed by Cursor/Claude or fall back to $PWD)
workspace="${WORKSPACE:-${PWD}}"
workspace=$(cd "$workspace" && pwd)  # canonicalize

# Function to check if a path is safe
is_safe_path() {
  local path="$1"
  # Expand and canonicalize
  path=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)/$(basename "$path") 2>/dev/null || true
  
  [[ -z "$path" ]] && return 1
  
  # Allowed: inside workspace or /tmp
  if [[ "$path" == "$workspace"/* ]] || [[ "$path" == /tmp/* ]] || [[ "$path" == "$workspace" ]]; then
    return 0
  fi
  return 1
}

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
