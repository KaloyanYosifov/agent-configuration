#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[install]${NC} $1"; }
info() { echo -e "${BLUE}  copied${NC}  $1"; }
warn() { echo -e "${YELLOW}  warn${NC}    $1"; }
err()  { echo -e "${RED}  error${NC}   $1" >&2; }

# ---------------------------------------------------------------------------
# Copy helpers
# ---------------------------------------------------------------------------

copy_dir() {
    local src="${1%/}"   # strip trailing slash
    local dest_dir="$2"
    local name
    name="$(basename "$src")"
    local dest="$dest_dir/$name"

    rm -rf "$dest"
    cp -r "$src" "$dest"
    info "$src -> $dest"
}

copy_file() {
    local src="$1"
    local dest="$2"

    cp "$src" "$dest"
    info "$src -> $dest"
}

# ---------------------------------------------------------------------------
# Install skills into a single target (e.g. ~/.claude)
# ---------------------------------------------------------------------------

install_skills_to() {
    local target="$1"

    mkdir -p "$target/skills"

    local count=0
    for d in "$SCRIPT_DIR/skills"/*/; do
        [[ -d "$d" ]] || continue
        copy_dir "$d" "$target/skills"
        (( count++ )) || true
    done

    if [[ $count -gt 0 ]]; then
        log "Installed $count skill(s) to $target/skills"
    fi
}

# ---------------------------------------------------------------------------
# Install agents into a single target (e.g. ~/.claude)
# ---------------------------------------------------------------------------

install_agents_to() {
    local target="$1"

    mkdir -p "$target/agents"

    local count=0
    for d in "$SCRIPT_DIR/agents"/*/; do
        [[ -d "$d" ]] || continue
        copy_dir "$d" "$target/agents"
        (( count++ )) || true
    done

    if [[ $count -gt 0 ]]; then
        log "Installed $count agents(s) to $target/agents"
    fi
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

    # Copy every hook script (replaces existing files)
    for f in "$hooks_src"/*.sh; do
        [[ -f "$f" ]] || continue
        local dest_file="$hooks_dest/$(basename "$f")"
        cp "$f" "$dest_file"
        chmod +x "$dest_file"
        info "$f -> $dest_file"
    done

    # Merge hook config into the appropriate settings file
    case "$target" in
        */.claude)  _merge_claude_hooks  "$target" ;;
        */.cursor)  _merge_cursor_hooks  "$target" ;;
    esac
}

# Merge the "claude" section of agent-hooks.json into ~/.claude/settings.json.
# Adds only hook entries whose "command" is not already present; never removes
# existing hooks or other settings fields.
_merge_claude_hooks() {
    local target="$1"
    local settings="$target/settings.json"

    python3 - "$settings" "$SCRIPT_DIR/agent-hooks.json" <<'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
hooks_json_path = sys.argv[2]

# Load (or initialise) settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

settings.setdefault("hooks", {})

# Load desired hooks from agent-hooks.json
with open(hooks_json_path) as f:
    desired_config = json.load(f)
desired = desired_config.get("claude", {}).get("hooks", {})

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
            # Preserve matcher, if, timeout, etc. (required for PreToolUse groups)
            new_entry = dict(entry)
            new_entry["hooks"] = new_hooks
            existing.append(new_entry)
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
    local hooks_file="$target/hooks.json"

    python3 - "$hooks_file" "$SCRIPT_DIR/agent-hooks.json" <<'PYEOF'
import json, sys, os

hooks_file_path = sys.argv[1]
hooks_json_path = sys.argv[2]

# Load (or initialise) hooks.json
if os.path.exists(hooks_file_path):
    with open(hooks_file_path) as f:
        config = json.load(f)
else:
    config = {}

config.setdefault("version", 1)
config.setdefault("hooks", {})

# Load desired hooks from agent-hooks.json
with open(hooks_json_path) as f:
    desired_config = json.load(f)
desired = desired_config.get("cursor", {}).get("hooks", {})

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
  --targets=...   Comma-separated list of target dirs; may be repeated (default: ~/.claude,~/.cursor,~/.agents)
  --targets PATH  Same as --targets=PATH (next argument)
  -h, --help      Show this help

Examples:
  ./install.sh
  ./install.sh --targets=~/.claude
  ./install.sh --targets=~/.claude,~/.cursor
  ./install.sh --targets=~/.claude --targets=~/.cursor
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

DEFAULT_TARGETS=("$HOME/.claude" "$HOME/.cursor" "$HOME/.agents")
TARGETS=()
_targets_from_flags=0

_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_append_targets_csv() {
    local csv="$1"
    [[ -z "$csv" ]] && return
    local parts
    IFS=',' read -ra parts <<< "$csv"
    local t
    for t in "${parts[@]}"; do
        t="$(_trim "$t")"
        [[ -z "$t" ]] && continue
        t="${t/#\~/$HOME}"
        TARGETS+=("$t")
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --targets=*)
            if [[ $_targets_from_flags -eq 0 ]]; then
                TARGETS=()
                _targets_from_flags=1
            fi
            _append_targets_csv "${1#--targets=}"
            shift
            ;;
        --targets)
            if [[ $# -lt 2 ]]; then
                err "--targets requires a value"
                usage
                exit 1
            fi
            if [[ $_targets_from_flags -eq 0 ]]; then
                TARGETS=()
                _targets_from_flags=1
            fi
            _append_targets_csv "$2"
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

[[ $_targets_from_flags -eq 0 ]] && TARGETS=("${DEFAULT_TARGETS[@]}")

for target in "${TARGETS[@]}"; do
    log "Installing to $target..."
    install_skills_to "$target"
    install_agents_to "$target"
    install_hooks_to  "$target"
done

log "All done."
