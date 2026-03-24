#!/bin/bash
# Works for both Cursor (hooks.json) and Claude Code (settings.json hooks).
# Notifies the user before shell/MCP execution, then passes through so the agent
# can still show its own approval UI.
json=$(cat)
name=$(printf '%s' "$json" | python3 -c "
import json, os, sys
d = json.load(sys.stdin)
roots = d.get('workspace_roots') or []
if roots:
    print(os.path.basename(roots[0].rstrip('/')) or 'Workspace')
elif d.get('cwd'):
    print(d['cwd'].rstrip('/').split('/')[-1] or 'Workspace')
else:
    print(os.path.basename(os.getcwd()) or 'Workspace')
")

case "$0" in
    */.cursor/*) agent="Cursor" ;;
    */.claude/*) agent="Claude" ;;
    *)           agent="Agent"  ;;
esac

osascript -e "display notification \"$agent is waiting for approval (or running): $name\" with title \"$agent\" sound name \"Ping\""
printf '%s\n' '{"continue":true,"permission":"ask"}'
