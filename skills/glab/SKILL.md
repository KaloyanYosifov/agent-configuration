---
name: glab
description: Use the `glab` CLI to interact with GitLab. Trigger this skill whenever the user shares a GitLab URL, mentions a GitLab repo, issue, merge request, pipeline, or asks anything about GitLab projects. Do not use the web browser or API directly — always use `glab` commands. Trigger even if the user says things like "check this MR", "what's the status of this pipeline", "open an issue", "list my repos", or pastes a gitlab.com link.
---

# glab Skill

Use the `glab` CLI for all GitLab interactions. Never use curl or the GitLab web API directly when `glab` can do the job.

## Extracting context from GitLab URLs

When the user shares a URL like `https://gitlab.com/namespace/project/-/issues/42`, parse it:
- `namespace/project` → the repo path
- The path segment after `/-/` → the resource type (issues, merge_requests, pipelines, etc.)
- The trailing number → the resource ID

## Common commands

**Repos**
```bash
glab repo clone namespace/project
glab repo view namespace/project
```

**Issues**
```bash
glab issue list -R namespace/project
glab issue view 42 -R namespace/project
glab issue create -R namespace/project --title "..." --description "..."
glab issue close 42 -R namespace/project
```

**Merge Requests**
```bash
glab mr list -R namespace/project
glab mr view 42 -R namespace/project
glab mr create -R namespace/project
glab mr merge 42 -R namespace/project
glab mr checkout 42 -R namespace/project
```

**Pipelines & CI**
```bash
glab ci list -R namespace/project
glab ci view -R namespace/project
glab ci run -R namespace/project
```

**Auth check**
```bash
glab auth status
```

## Behavior rules

- Always pass `-R namespace/project` explicitly unless you're already inside the repo directory.
- If `glab` returns an error about authentication, tell the user to run `glab auth login`.
- If the user pastes a GitLab URL, extract the repo path and resource from it — don't ask them to repeat the information.
- Prefer `glab` output as-is over reformatting unless the user asks for a summary.
- If the user asks to "open" something from GitLab, use `glab <resource> view` first. Open in browser only if they explicitly ask.
