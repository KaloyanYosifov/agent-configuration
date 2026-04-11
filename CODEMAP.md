# CODEMAP.md - Agent Config

## Overview

Centralized AI agent workflow config (Claude Code, Cursor). Reusable skills, hooks, agents.

---

## Architecture

```dot
digraph agent_config {
    rankdir=TB;

    subgraph cluster_project {
        label="agent-configuration";

        subgraph cluster_skills {
            label="Skills";
            tdd["test-driven-development"];
            excalidraw["excalidraw"];
            deep_research["deep-research"];
            subagent["subagent-driven-development"];
        }

        subgraph cluster_hooks {
            label="Hooks";
            notify_perm["notify-permission.sh"];
            notify_done["notify-done.sh"];
            block_danger["block-dangerous.sh"];
        }

        subgraph cluster_agents {
            label="Agents";
            code_reviewer["code-reviewer.md"];
        }

        install["install.sh"];
        hooks_json["agent-hooks.json"];
    }

    subgraph cluster_targets {
        label="Targets";

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
}
```

---

## Directory

```
agent-configuration/
├── install.sh                 # Symlinks to targets
├── agent-hooks.json           # Hook config template
├── CODEMAP.md                 # This file
├── skills/                    # Reusable capabilities
│   ├── test-driven-development/
│   ├── subagent-driven-development/
│   ├── deep-research/
│   ├── excalidraw/
│   ├── web-fetch/
│   ├── web-search/
│   ├── glab/
│   ├── brainstorming/
│   ├── humanizer/
│   ├── verification-before-completion/
│   ├── dispatching-parallel-agents/
│   ├── executing-plans/
│   ├── mlx-whisper/
│   └── writing-plans/
├── hooks/                     # Lifecycle interceptors
│   ├── notify-permission.sh
│   ├── notify-done.sh
│   └── block-dangerous.sh
└── agents/                    # Specialized subagents
    └── code-reviewer.md
```

---

## Core Components

### Skills

| Skill | Purpose | Trigger |
|-------|---------|--------|
| `test-driven-development` | TDD methodology | Before production code |
| `subagent-driven-development` | Parallel task execution | Implementation plans |
| `deep-research` | Multi-angle web research | Current info needed |
| `excalidraw` | Hand-drawn diagrams | User requests |
| `glab` | GitLab CLI | GitLab mentions |
| `brainstorming` | Creative exploration | New features |
| `humanizer` | Remove AI patterns | Text review |
| `verification-before-completion` | Verify before done | Before marking complete |
| `dispatching-parallel-agents` | Parallel agent work | Multiple tasks |
| `executing-plans` | Plan execution | Separate session |
| `mlx-whisper` | Speech-to-text | Audio files |
| `writing-plans` | Implementation plans | Multi-step tasks |
| `web-fetch` | Page content | Realtime info |
| `web-search` | Web search | Current events |

### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| `notify-permission.sh` | `beforeShellExecution`/`beforeMCPToolExecution` (Cursor)<br>`Notification` (Claude) | macOS notification on permission |
| `notify-done.sh` | `stop` | macOS notification on finish |
| `block-dangerous.sh` | `beforeShellExecution` (Cursor)<br>`PreToolUse:Bash` (Claude) | Blocks rm -rf, git reset --hard, etc. |

### Agents

| Agent | Purpose |
|-------|--------|
| `code-reviewer.md` | Standardized code review |

---

## Installation

### install.sh

1. Symlink skills to target
2. Symlink agents to target
3. Symlink hooks + merge agent-hooks.json into config

### agent-hooks.json

Template with `$HOOKS_DIR` placeholder.

### Targets

| Target | Skills | Hooks | Config |
|--------|--------|-------|--------|
| `~/.claude` | `.claude/skills/` | `.claude/hooks/` | `.claude/settings.json` |
| `~/.cursor` | `.cursor/skills/` | `.cursor/hooks/` | `.cursor/hooks.json` |
| `~/.agents` | `.agents/skills/` | `.agents/hooks/` | N/A |

---

## Data Flow

### Skill Invocation

```
User: @test-driven-development implement X
     |
     v
Claude/Cursor reads skills/test-driven-development/SKILL.md
     |
     v
Follows TDD methodology
```

### Hook Execution (Claude Code)

```
User: git status
     |
     v
PreToolUse:Bash hook triggers
     |
     +-> block-dangerous.sh (exit 2=block, 0=allow)
     +-> rtk-rewrite.sh (rewrites to rtk git status)
     |
     v
Command executes (if not blocked)
```

### Hook Execution (Cursor)

```
User: ls -la
     |
     v
beforeShellExecution hook triggers
     |
     +-> block-dangerous.sh (prints {"continue": true})
     +-> notify-permission.sh (macOS notification)
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
         +-> code-quality-reviewer subagent
```

---

## Usage

### Skill

```bash
@test-driven-development Write function that parses CSV
```

### Install to custom target

```bash
./install.sh --targets=~/.my-agent-config
```

### Blocked command

```bash
rm -rf /important/data
# Blocked: 'rm -rf /important/data' matches pattern 'rm -rf'.
# Propose safer alternative.
```
