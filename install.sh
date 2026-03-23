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

# ---------------------------------------------------------------------------
# Install into a single target (e.g. ~/.claude)
# ---------------------------------------------------------------------------

install_to() {
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
    install_to "$target"
done

log "All done."
