#!/usr/bin/env python3
"""
Universal permission/notification hook for both Cursor and Claude Code.

Cursor hooks (beforeShellExecution, beforeMCPToolExecution):
  - Notifies the user about the pending action.
  - Prints {"continue": true} so Cursor still shows its approval UI.

Claude Code hook (Notification):
  - Notifies the user when Claude needs attention (e.g. permission request).
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
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", " ")
    if len(s) > 200:
        s = s[:197] + "..."
    return s


def notify(msg: str, agent: str) -> None:
    body = applescript_string(msg)
    script = f'display notification "{body}" with title "{agent}" sound name "Ping"'
    subprocess.run(["osascript", "-e", script], check=False)


def main() -> None:
    try:
        d = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if d.get("is_interrupt"):
        sys.exit(0)

    agent = agent_label()
    name = workspace_label(d)

    # Cursor before* hooks: tool_name / command present, no failure_type
    tool = d.get("tool_name") or d.get("command") or ""
    if tool and "failure_type" not in d:
        label = tool if len(tool) <= 60 else tool[:57] + "..."
        notify(f"{agent} wants to run: {label} ({name})", agent)
        # Cursor beforeShellExecution / beforeMCPExecution expect permission (and often continue).
        print(json.dumps({"continue": True, "permission": "allow"}))
        return

    # Claude Code Notification hook / Cursor postToolUseFailure
    ft = d.get("failure_type") or ""
    reason = d.get("reason") or ""
    if ft not in ("permission_denied", "error", "timeout") and not reason:
        sys.exit(0)

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

    notify(msg, agent)


if __name__ == "__main__":
    main()
