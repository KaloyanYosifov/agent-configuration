#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[install]${NC} $1"; }
info() { echo -e "${BLUE}  linked${NC}  $1"; }
warn() { echo -e "${YELLOW}  warn${NC}    $1"; }
err()  { echo -e "${RED}  error${NC}   $1" >&2; }

# ---------------------------------------------------------------------------
# Linking helpers
# ---------------------------------------------------------------------------

link_dir() {
    local src="$1"
    local dest_dir="$2"
    local name
    name="$(basename "$src")"
    local dest="$dest_dir/$name"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        warn "Skipping $dest — exists as a real directory (remove it manually to replace)"
        return
    fi

    ln -sf "$src" "$dest"
    info "$src -> $dest"
}

link_file() {
    local src="$1"
    local dest="$2"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        warn "Skipping $dest — exists as a real file (remove it manually to replace)"
        return
    fi

    ln -sf "$src" "$dest"
    info "$src -> $dest"
}

# ---------------------------------------------------------------------------
# Install skills into a single target (e.g. ~/.claude)
# ---------------------------------------------------------------------------

install_skills_to() {
    local target="$1"

    mkdir -p "$target/skills"

    local count=0
    for d in "$SCRIPT_DIR/skills/"/*/; do
        [[ -d "$d" ]] || continue
        link_dir "$d" "$target/skills"
        (( count++ )) || true
    done

    [[ $count -gt 0 ]] && log "Installed $count skill(s) to $target/skills"
}

# ---------------------------------------------------------------------------
# Install hooks: link hook files, then merge config
# ---------------------------------------------------------------------------

install_hooks_to() {
    local target="$1"   # e.g. ~/.claude or ~/.cursor

    local hooks_src="$SCRIPT_DIR/hooks"
    [[ -d "$hooks_src" ]] || return 0

    local hooks_dest="$target/hooks"
    mkdir -p "$hooks_dest"

    # Link every hook script (symlink; replaces existing symlinks or real files)
    for f in "$hooks_src"/*.sh; do
        [[ -f "$f" ]] || continue
        local dest_file="$hooks_dest/$(basename "$f")"
        chmod +x "$f"
        ln -sf "$f" "$dest_file"
        info "$f -> $dest_file"
    done

    # Merge hook config into the appropriate settings file
    case "$target" in
        */.claude)  _merge_claude_hooks  "$target" "$hooks_dest" ;;
        */.cursor)  _merge_cursor_hooks  "$target" "$hooks_dest" ;;
    esac
}

# Merge the "claude" section of agent-hooks.json into ~/.claude/settings.json.
# Adds only hook entries whose "command" is not already present; never removes
# existing hooks or other settings fields.
_merge_claude_hooks() {
    local target="$1"
    local hooks_dest="$2"
    local settings="$target/settings.json"

    python3 - "$settings" "$SCRIPT_DIR/agent-hooks.json" "$hooks_dest" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
hooks_json_path = sys.argv[2]
hooks_dest = sys.argv[3]

# Load (or initialise) settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

settings.setdefault("hooks", {})

# Load desired hooks from agent-hooks.json, substituting $HOOKS_DIR
with open(hooks_json_path) as f:
    raw = f.read().replace("$HOOKS_DIR", hooks_dest)
desired = json.loads(raw).get("claude", {}).get("hooks", {})

changed = False
for event, entries in desired.items():
    existing = settings["hooks"].setdefault(event, [])
    existing_cmds = set()
    for entry in existing:
        for h in entry.get("hooks", []):
            existing_cmds.add(h.get("command", ""))
    for entry in entries:
        new_hooks = [h for h in entry.get("hooks", [])
                     if h.get("command", "") not in existing_cmds]
        if new_hooks:
            existing.append({"hooks": new_hooks})
            for h in new_hooks:
                existing_cmds.add(h.get("command", ""))
            changed = True

if changed:
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print(f"  updated  {settings_path}")
else:
    print(f"  up-to-date {settings_path}")
PYEOF
}

# Merge the "cursor" section of agent-hooks.json into ~/.cursor/hooks.json.
# Adds only entries whose "command" is not already present; preserves existing hooks.
_merge_cursor_hooks() {
    local target="$1"
    local hooks_dest="$2"
    local hooks_file="$target/hooks.json"

    python3 - "$hooks_file" "$SCRIPT_DIR/agent-hooks.json" "$hooks_dest" <<'PYEOF'
import json, sys, os

hooks_file_path = sys.argv[1]
hooks_json_path = sys.argv[2]
hooks_dest = sys.argv[3]

# Load (or initialise) hooks.json
if os.path.exists(hooks_file_path):
    with open(hooks_file_path) as f:
        config = json.load(f)
else:
    config = {}

config.setdefault("version", 1)
config.setdefault("hooks", {})

# Load desired hooks from agent-hooks.json, substituting $HOOKS_DIR
with open(hooks_json_path) as f:
    raw = f.read().replace("$HOOKS_DIR", hooks_dest)
desired = json.loads(raw).get("cursor", {}).get("hooks", {})

changed = False
for event, entries in desired.items():
    existing = config["hooks"].setdefault(event, [])
    existing_cmds = {e.get("command", "") for e in existing}
    for entry in entries:
        cmd = entry.get("command", "")
        if cmd and cmd not in existing_cmds:
            existing.append(entry)
            existing_cmds.add(cmd)
            changed = True

if changed:
    with open(hooks_file_path, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print(f"  updated  {hooks_file_path}")
else:
    print(f"  up-to-date {hooks_file_path}")
PYEOF
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --targets=...   Comma-separated list of target dirs (default: ~/.claude,~/.cursor,~/.agents)
  -h, --help      Show this help

Examples:
  ./install.sh
  ./install.sh --targets=~/.claude
  ./install.sh --targets=~/.claude,~/.cursor
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TARGETS=("$HOME/.claude" "$HOME/.cursor" "$HOME/.agents")

for arg in "$@"; do
    case "$arg" in
        --targets=*)
            IFS=',' read -ra TARGETS <<< "${arg#--targets=}"
            TARGETS=("${TARGETS[@]/#\~/$HOME}")
            ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

for target in "${TARGETS[@]}"; do
    log "Installing to $target..."
    install_skills_to "$target"
    install_hooks_to  "$target"
done

log "All done."
