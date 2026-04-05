---
name: agent-hooks-registration
description: Registers new agent hook scripts in agent-hooks.json for this repo. Use whenever creating or adding a shell hook under hooks/, when the user asks to wire up a hook, or after AI generates any new hooks/*.sh so install.sh merges it into Cursor and Claude Code.
---

# Register hooks in `agent-hooks.json`

This repository installs hooks by symlinking `hooks/*.sh` into each target and **merging** [`agent-hooks.json`](../../agent-hooks.json) into `~/.cursor/hooks.json` and `~/.claude/settings.json`. A script on disk alone is not enough: it must be listed in `agent-hooks.json` or the agent will never invoke it.

## When to apply

- You (or the user) created a new file under `hooks/`.
- You edited a hook script and it should run on a new lifecycle event.
- The user says “add a hook”, “wire up the hook”, or “register the hook”.

## Steps

1. **Open** [`agent-hooks.json`](../../agent-hooks.json) at the repo root (same directory as `install.sh`).

2. **Use the `$HOOKS_DIR` placeholder** in every `command` path. `install.sh` replaces it with the real `hooks` directory for that install target (for example `~/.cursor/hooks`). Never hardcode `~` or absolute paths in this file.

3. **Cursor** (`cursor.hooks`): each event is an array of objects with a `command` string (see existing `beforeShellExecution`, `beforeMCPToolExecution`, `stop`). Add an object for the right event name. Put blocking or guard hooks **before** notification-style hooks when order matters (for example `beforeShellExecution`). shape depends on the event (see [Cursor hooks reference](https://cursor.com/docs/hooks)):

4. **Claude Code** (`claude.hooks`): shape depends on the event (see [Claude Code hooks reference](https://code.claude.com/docs/en/hooks)):
   - **Tool-scoped events** (`PreToolUse`, `PostToolUse`, etc.): add a **matcher group** — an object with `matcher` (for example `"Bash"`) and a `hooks` array of handlers. Each handler needs `"type": "command"` and `"command": "$HOOKS_DIR/your-script.sh"`.
   - **Simple events** (`Notification`, `Stop`, …): follow the existing pattern — an array of objects that contain only a `hooks` array with `type` + `command`.

5. **Avoid duplicates**: `install.sh` only appends handlers whose `command` string is not already present in the user’s merged config. Use a single canonical path per script.

6. **Tell the user** to re-run `./install.sh` (or their usual targets) so the merge runs, unless they only use project-local hook config.

## Quick reference

| Agent  | Config merged into        | Block dangerous shell (this repo)        |
|--------|---------------------------|------------------------------------------|
| Cursor | `~/.cursor/hooks.json`    | `beforeShellExecution` → `block-dangerous.sh` |
| Claude | `~/.claude/settings.json` | `PreToolUse` / `matcher: "Bash"` → `block-dangerous.sh` |

## Checklist before finishing

- [ ] New hook script lives under `hooks/` and is executable (install sets `+x` on sources).
- [ ] `agent-hooks.json` updated for **both** Cursor and Claude when the hook should run in both.
- [ ] Commands use `$HOOKS_DIR/...` only.
- [ ] Matcher groups for Claude preserve `matcher` at the group level (do not flatten into `Notification`-style entries).
