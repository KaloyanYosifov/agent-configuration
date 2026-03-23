---
name: web-search
description: Use this skill to search the web. Trigger when the user asks about recent events, latest versions, today's news, or anything that requires up-to-date information.
---

# Web Search

## Overview

Two standalone Python scripts for searching the web and fetching page content. Both run locally using DuckDuckGo and direct HTTP requests — no external API keys or services required.

The scripts live next to this file in `scripts/`.

## web_search.py — Search the Web

```bash
python3 scripts/web_search.py --query "your search query"
python3 scripts/web_search.py --query "your query" --max-results 10
python3 scripts/web_search.py --query "your query" --output-file results.json
```

Parameters:
- `--query` (required): Search query string
- `--max-results` (optional): Number of results, default 5
- `--output-file` (optional): Save JSON results to this path

Output: JSON array with `title`, `url`, and `snippet` for each result.

## Typical Workflow

1. Search for the topic using the web_search.py script
2. Aggregate headlines and urls
3. Follow links by using the web-fetch skill to fetch more information

```bash
python3 scripts/web_search.py --query "FastAPI 0.115 changelog" --max-results 5
```

## Notes

- For time-sensitive queries, include the year or month in your search query
- Dependencies: `ddgs`, `requests`, `readabilipy`, `markdownify` (fallback: `beautifulsoup4`)
