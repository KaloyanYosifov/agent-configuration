#!/usr/bin/env python3
"""
Works for both Cursor (postToolUseFailure) and Claude Code (Notification hook).
Shows a macOS notification when a tool fails, times out, or hits permission_denied.
Skips user-initiated interrupts.

Note: Cursor has no hook that fires exactly when the approval dialog first appears;
permission_denied runs after a denial/block, not at the moment the UI is waiting.
"""
import json
import os
import subprocess
import sys


def workspace_label(d: dict) -> str:
    roots = d.get("workspace_roots") or []
    if roots:
        return os.path.basename(roots[0].rstrip("/")) or "Workspace"
    cwd = d.get("cwd")
    if cwd:
        return cwd.rstrip("/").split("/")[-1] or "Workspace"
    return os.path.basename(os.getcwd()) or "Workspace"


def agent_label() -> str:
    path = sys.argv[0]
    if "/.cursor/" in path:
        return "Cursor"
    if "/.claude/" in path:
        return "Claude"
    return "Agent"


def applescript_string(s: str) -> str:
    """Escape for AppleScript double-quoted string literal."""
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", " ")
    if len(s) > 200:
        s = s[:197] + "..."
    return s


def main() -> None:
    try:
        d = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if d.get("is_interrupt"):
        sys.exit(0)

    ft = d.get("failure_type") or ""
    # Claude Code uses "reason" field for Notification events; treat those too.
    reason = d.get("reason") or ""
    if ft not in ("permission_denied", "error", "timeout") and not reason:
        sys.exit(0)

    agent = agent_label()
    name = workspace_label(d)
    err = (d.get("error_message") or "").strip()

    if reason:
        msg = f"{reason} ({name})"
    elif ft == "permission_denied":
        msg = f"Permission denied or blocked ({name})"
    else:
        msg = f"Tool {ft} ({name})"
    if err:
        tail = err if len(err) <= 120 else err[:117] + "..."
        msg = f"{msg}: {tail}"

    body = applescript_string(msg)
    script = f'display notification "{body}" with title "{agent}" sound name "Ping"'
    subprocess.run(["osascript", "-e", script], check=False)


if __name__ == "__main__":
    main()
