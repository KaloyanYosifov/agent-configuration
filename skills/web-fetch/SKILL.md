---
name: web-fetch
description: Use this skill to fetch information from a url. Trigger when the user provides a url and you need to get up to date information
---

# Web Fetch

## Overview

A standalone Python scripts for searching the web and fetching page content. Runs locally using DuckDuckGo.

The scripts live next to this file in `scripts/`.


## web_fetch.py — Fetch a Web Page

```bash
python3 scripts/web_fetch.py --url https://example.com
python3 scripts/web_fetch.py --url https://example.com --max-length 8000
python3 scripts/web_fetch.py --url https://example.com --output-file page.md
```

Parameters:
- `--url` (required): Full URL including `https://`
- `--timeout` (optional): Request timeout in seconds, default 10
- `--max-length` (optional): Max characters to return, default 4096
- `--output-file` (optional): Save markdown content to this path

Output: Extracted page content as Markdown.

## Typical Workflow

1. Search for relevant URLs on the topic
2. Fetch the most relevant pages to read full content
3. Synthesize findings and answer the user

```bash
python3 scripts/web_fetch.py --url https://fastapi.tiangolo.com/release-notes/ --max-length 8000
```

## Notes

- Always include `https://` in URLs passed to `web_fetch.py`
- If a page fails to fetch, search for a cached or summarized version instead
