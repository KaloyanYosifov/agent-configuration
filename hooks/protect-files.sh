#!/usr/bin/env bash
set -euo pipefail

# Read stdin
input=""
while IFS= read -r line || [[ -n "$line" ]]; do
  input+="$line"
done
[[ -z "$input" ]] && exit 0

# Detect Cursor context (hook is symlinked into ~/.cursor/hooks/)
is_cursor=0
if [[ "${BASH_SOURCE[0]:-}" == *".cursor"* ]] || [[ "$0" == *".cursor"* ]]; then
  is_cursor=1
fi

# Claude: tool_input.file_path (Edit) or tool_input.path (Write)
# Cursor beforeFileModification: top-level path or file_path
file=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .path // .file_path // ""')

protected=(
  ".env*"
  ".git/*"
  "package-lock.json"
  "yarn.lock"
  "*.pem"
  "*.key"
  "secrets/*"
)

for pattern in "${protected[@]}"; do
  if echo "$file" | grep -qiE "^${pattern//\*/.*}$"; then
    echo "Blocked: '$file' is protected. Explain why this edit is necessary." >&2
    exit 2
  fi
done

[[ $is_cursor -eq 1 ]] && echo '{"continue": true}'
exit 0
