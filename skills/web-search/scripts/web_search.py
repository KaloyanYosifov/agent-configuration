"""
Web search using DuckDuckGo. No API key required.

Usage:
    python web_search.py --query "your search query"
    python web_search.py --query "your query" --max-results 10
    python web_search.py --query "your query" --output-file /path/to/results.json
"""

import argparse
import json
import sys


def search(query: str, max_results: int = 5) -> list[dict]:
    try:
        from ddgs import DDGS
    except ImportError:
        print("Error: ddgs not installed. Run: pip install ddgs", file=sys.stderr)
        sys.exit(1)

    ddgs = DDGS(timeout=30)
    try:
        results = ddgs.text(query, max_results=max_results)
        return list(results) if results else []
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return []


def main():
    parser = argparse.ArgumentParser(description="Search the web using DuckDuckGo")
    parser.add_argument("--query", required=True, help="Search query")
    parser.add_argument("--max-results", type=int, default=5, help="Max results (default: 5)")
    parser.add_argument("--output-file", help="Save results as JSON to this path")
    args = parser.parse_args()

    results = search(args.query, args.max_results)

    normalized = [
        {
            "title": r.get("title", ""),
            "url": r.get("href", ""),
            "snippet": r.get("body", ""),
        }
        for r in results
    ]

    output = json.dumps(normalized, indent=2, ensure_ascii=False)

    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"Saved {len(normalized)} results to {args.output_file}")
    else:
        print(output)


if __name__ == "__main__":
    main()
