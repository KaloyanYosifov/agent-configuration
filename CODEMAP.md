# CODEMAP.md - Agent Configuration Project

## Overview

A centralized configuration repository for AI agent workflows (Claude Code and Cursor), providing reusable skills, hooks, and agents that enhance productivity and enforce best practices.

---

## Architecture Diagram

```dot
digraph agent_config {
    rankdir=TB;

    subgraph cluster_project {
        label="agent-configuration (source of truth)";

        subgraph cluster_skills {
            label="Skills (reusable capabilities)";
            tdd["test-driven-development"];
            excalidraw["excalidraw"];
            deep_research["deep-research"];
            subagent["subagent-driven-development"];
        }

        subgraph cluster_hooks {
            label="Hooks (lifecycle interceptors)";
            notify_perm["notify-permission.sh"];
            notify_done["notify-done.sh"];
            block_danger["block-dangerous.sh"];
        }

        subgraph cluster_agents {
            label="Agents (specialized subagents)";
            code_reviewer["code-reviewer.md"];
        }

        install["install.sh"];
        hooks_json["agent-hooks.json"];
    }

    subgraph cluster_targets {
        label="Target Directories";

        subgraph cluster_claude {
            label="~/.claude";
            claude_skills["skills/"];
            claude_hooks["hooks/"];
            settings["settings.json"];
        }

        subgraph cluster_cursor {
            label="~/.cursor";
            cursor_skills["skills/"];
            cursor_hooks["hooks/"];
            hooks_json_cursor["hooks.json"];
        }
    }

    install -> claude_skills, cursor_skills;
    install -> claude_hooks, cursor_hooks;
    hooks_json -> settings, hooks_json_cursor;

    style cluster_project fill:#f0f0f0,stroke:#333;
    style cluster_targets fill:#e8f4fc,stroke:#333;
}
```

---

## Directory Structure

```
agent-configuration/
├── install.sh                 # Installation script (symlinks to targets)
├── agent-hooks.json           # Hook configuration template
├── CODEMAP.md                 # This file
│
├── skills/                    # Reusable capabilities
│   ├── test-driven-development/
│   │   ├── SKILL.md          # TDD methodology
│   │   └── testing-anti-patterns.md
│   ├── subagent-driven-development/
│   │   ├── SKILL.md          # Parallel task execution
│   │   ├── implementer-prompt.md
│   │   ├── spec-reviewer-prompt.md
│   │   └── code-quality-reviewer-prompt.md
│   ├── deep-research/
│   │   └── SKILL.md          # Systematic web research
│   ├── excalidraw/
│   │   ├── SKILL.md          # Diagram generation
│   │   ├── references/
│   │   └── scripts/
│   ├── web-fetch/
│   ├── web-search/
│   ├── glab/                 # GitLab CLI
│   ├── brainstorming/
│   ├── humanizer/
│   ├── verification-before-completion/
│   ├── dispatching-parallel-agents/
│   ├── executing-plans/
│   ├── mlx-whisper/          # Speech-to-text
│   └── writing-plans/
│
├── hooks/                     # Lifecycle interceptors
│   ├── notify-permission.sh   # macOS notifications on permission requests
│   ├── notify-done.sh         # macOS notifications on completion
│   └── block-dangerous.sh     # Blocks dangerous commands
│
└── agents/                    # Specialized subagents
    └── code-reviewer.md       # Code review agent template
```

---

## Core Components

### Skills

Skills are reusable capabilities loaded via `@skill-name` syntax.

| Skill | Purpose | Trigger |
|-------|---------|--------|
| `test-driven-development` | Enforces TDD methodology | Before writing production code |
| `subagent-driven-development` | Parallel task execution with review | Executing implementation plans |
| `deep-research` | Systematic multi-angle web research | Questions requiring current info |
| `excalidraw` | Hand-drawn style diagram generation | User requests diagrams |
| `glab` | GitLab CLI interaction | GitLab URLs or mentions |
| `brainstorming` | Creative exploration before implementation | New features, creative work |
| `humanizer` | Remove AI-generated writing patterns | Editing/reviewing text |
| `verification-before-completion` | Run verification before claiming done | Before marking work complete |
| `dispatching-parallel-agents` | Coordinate parallel agent work | Multiple independent tasks |
| `executing-plans` | Execute plans in parallel session | Plan execution (separate session) |
| `mlx-whisper` | Local speech-to-text transcription | Audio files present |
| `writing-plans` | Create implementation plans | Multi-step tasks |
| `web-fetch` | Fetch full page content | Need realtime info |
| `web-search` | Web search capability | Current events, latest info |

### Hooks

Hooks intercept lifecycle events for both Claude Code and Cursor.

#### Hook Files

| Hook | Event | Description |
|------|-------|-------------|
| `notify-permission.sh` | `beforeShellExecution` / `beforeMCPToolExecution` (Cursor)<br>`Notification` (Claude) | Shows macOS notification when agent needs permission |
| `notify-done.sh` | `stop` | Shows macOS notification when agent finishes |
| `block-dangerous.sh` | `beforeShellExecution` (Cursor)<br>`PreToolUse:Bash` (Claude) | Blocks dangerous commands (rm -rf, git reset --hard, etc.) |

#### Hook Flow Diagram

```dot
digraph hook_flow {
    rankdir=LR;

    subgraph cluster_cursor {
        label="Cursor Hooks";
        before_shell["beforeShellExecution"] -> block_dangerous["block-dangerous.sh"] -> notify_perm["notify-permission.sh"];
        before_mcp["beforeMCPToolExecution"] -> notify_perm;
        stop["stop"] -> notify_done["notify-done.sh"];
    }

    subgraph cluster_claude {
        label="Claude Code Hooks";
        pre_tool["PreToolUse:Bash"] -> block_dangerous_claude["block-dangerous.sh"] -> rtk["rtk-rewrite.sh"];
        notification["Notification"] -> notify_perm_claude["notify-permission.sh"];
        stop_claude["Stop"] -> notify_done_claude["notify-done.sh"];
    }
}
```

### Agents

Agents are specialized subagents for specific tasks.

| Agent | Purpose |
|-------|--------|
| `code-reviewer.md` | Performs code reviews following standardized template |

---

## Installation & Configuration

### install.sh

The installation script performs three operations:

1. **Link skills**: Symlinks all `skills/*/` directories to target's `skills/`
2. **Link agents**: Symlinks all `agents/*/` directories to target's `agents/`
3. **Link hooks & merge config**:
   - Symlinks hook scripts to target's `hooks/`
   - Merges `agent-hooks.json` into target's config:
     - Claude: `.claude/settings.json`
     - Cursor: `.cursor/hooks.json`

### agent-hooks.json

Template configuration with `$HOOKS_DIR` placeholder:

```json
{
  "cursor": {
    "hooks": {
      "beforeShellExecution": [{"command": "$HOOKS_DIR/notify-permission.sh"}],
      "stop": [{"command": "$HOOKS_DIR/notify-done.sh"}]
    }
  },
  "claude": {
    "hooks": {
      "Notification": [{"hooks": [{"command": "$HOOKS_DIR/notify-permission.sh"}]}],
      "Stop": [{"hooks": [{"command": "$HOOKS_DIR/notify-done.sh"}]}]
    }
  }
}
```

### Installation Targets

| Target | Skills Path | Hooks Path | Config File |
|--------|-------------|------------|-------------|
| `~/.claude` | `.claude/skills/` | `.claude/hooks/` | `.claude/settings.json` |
| `~/.cursor` | `.cursor/skills/` | `.cursor/hooks/` | `.cursor/hooks.json` |
| `~/.agents` | `.agents/skills/` | `.agents/hooks/` | N/A |

---

## Data Flow

### Skill Invocation

```
User: @test-driven-development implement feature X
     |
     v
Claude/Cursor reads skills/test-driven-development/SKILL.md
     |
     v
Follows TDD methodology from skill
```

### Hook Execution (Claude Code - Bash command)

```
User requests: git status
     |
     v
PreToolUse:Bash hook triggers
     |
     +-> block-dangerous.sh (exits 2 to block, 0 to allow)
     |
     +-> rtk-rewrite.sh (rewrites to rtk git status, saves tokens)
     |
     v
Command executes (if not blocked)
```

### Hook Execution (Cursor - Shell command)

```
User requests: ls -la
     |
     v
beforeShellExecution hook triggers
     |
     +-> block-dangerous.sh (prints {"continue": true} to allow)
     |
     +-> notify-permission.sh (shows macOS notification)
     |
     v
Command executes (if not blocked)
```

---

## Key Relationships

```
test-driven-development SKILL
         |
         | (enforced by)
         v
subagent-driven-development SKILL
         |
         | (uses for each task)
         v
implementer subagent
         |
         | (reviewed by)
         +-> spec-reviewer subagent
         |
         +-> code-quality-reviewer subagent
```

---

## Files Reference

### Source Files (in repo)

| File | Type | Description |
|------|------|-------------|
| `install.sh` | Bash | Installation script |
| `agent-hooks.json` | JSON | Hook config template |
| `skills/*/SKILL.md` | Markdown | Skill documentation |
| `hooks/*.sh` | Bash/Python | Hook scripts |
| `agents/*.md` | Markdown | Agent templates |

### Generated Files (in targets)

| File | Type | Description |
|------|------|-------------|
| `.claude/settings.json` | JSON | Claude Code config (merged) |
| `.cursor/hooks.json` | JSON | Cursor hooks config (merged) |
| `.claude/skills/*/` | Symlink | Skills symlinks |
| `.cursor/skills/*/` | Symlink | Skills symlinks |
| `.claude/hooks/*.sh` | Symlink | Hook symlinks |
| `.cursor/hooks/*.sh` | Symlink | Hook symlinks |

---

## Usage Examples

### Using a Skill

```bash
# In Claude/Cursor chat:
@test-driven-development Write a function that parses CSV
```

### Installing to Custom Target

```bash
./install.sh --targets=~/.my-agent-config
```

### Hook Blocking Example

```bash
# This command will be blocked:
rm -rf /important/data

# Error output:
Blocked: 'rm -rf /important/data' matches dangerous pattern 'rm -rf'.
Propose a safer alternative.
```
