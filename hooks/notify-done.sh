#!/bin/bash
# Works for both Cursor (hooks.json) and Claude Code (settings.json hooks).
# Reads JSON from stdin, derives workspace label, and shows a macOS notification.
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

# Detect agent by script path: hooks under ~/.cursor/ are Cursor, ~/.claude/ are Claude.
case "$0" in
    */.cursor/*) agent="Cursor" ;;
    */.claude/*) agent="Claude" ;;
    *)           agent="Agent"  ;;
esac

osascript -e "display notification \"$agent has finished: $name\" with title \"$agent\" sound name \"Glass\""
