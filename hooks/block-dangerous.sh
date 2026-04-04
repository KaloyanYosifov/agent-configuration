#!/usr/bin/env bash
#
# Blocks dangerous commands before execution for both Cursor and Claude Code.
#
# For Cursor: runs via beforeShellExecution hook
# For Claude: runs via PreToolUse hook (matcher: Bash)
#
# Exits with code 2 to block the command, or 0 to allow it.
# For Cursor: must print {"continue": true} to allow the command.
#

set -euo pipefail

# Read the input JSON from stdin
input=""
while IFS= read -r line || [[ -n "$line" ]]; do
  input+="$line"
done

[[ -z "$input" ]] && exit 0

# Extract the command based on which agent is calling us
# Cursor provides 'command', Claude provides 'tool_input.command'
if command -v jq >/dev/null 2>&1; then
  # Try Cursor format first, then Claude format
  cmd=$(echo "$input" | jq -r '.command // .tool_input.command // ""')
else
  exit 0
fi

[[ -z "$cmd" ]] && exit 0

# Dangerous patterns to block
declare -a dangerous_patterns=(
  "rm -rf"
  "git reset --hard"
  "git push.*--force"
  "DROP TABLE"
  "DROP DATABASE"
  "curl.*\\|.*sh"
  "wget.*\\|.*bash"
  "mkfs"
  "dd if=/dev/"
  ":(){ :|:& };:"
  "chmod -R 777"
)

# Check each pattern
for pattern in "${dangerous_patterns[@]}"; do
  if echo "$cmd" | grep -qiE "$pattern"; then
    echo "Blocked: '$cmd' matches dangerous pattern '$pattern'. Propose a safer alternative." >&2
    exit 2
  fi
done

# For Cursor: must print continue:true to allow the command
# For Claude: just exit 0 is enough
# Detect which agent based on argv[0] path
if [[ "${BASH_SOURCE[0]}" == *".cursor"* ]] || [[ "$0" == *".cursor"* ]]; then
  echo '{"continue": true}'
fi

exit 0
