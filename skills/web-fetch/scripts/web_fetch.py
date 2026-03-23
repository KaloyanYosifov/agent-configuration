"""
Fetch and extract readable content from a URL. No API key required.

Usage:
    python web_fetch.py --url https://example.com
    python web_fetch.py --url https://example.com --max-length 8000
    python web_fetch.py --url https://example.com --output-file /path/to/output.md
"""

import argparse
import sys


def fetch(url: str, timeout: int = 10, max_length: int = 10000) -> str:
    try:
        import requests
    except ImportError:
        print("Error: requests not installed. Run: pip install requests",
              file=sys.stderr)
        sys.exit(1)

    try:
        response = requests.get(
            url,
            timeout=timeout,
            headers={"User-Agent": "Mozilla/5.0 (compatible; DeerFlow/1.0)"},
        )
        response.raise_for_status()
        html = response.text
    except Exception as e:
        return f"Error fetching URL: {e}"

    return _extract_markdown(html, max_length)


def _extract_markdown(html: str, max_length: int) -> str:
    # Try readabilipy first (better quality, requires Node.js Readability.js)
    try:
        from readabilipy import simple_json_from_html_string
        from markdownify import markdownify as md

        article = simple_json_from_html_string(html, use_readability=True)
        title = article.get("title") or "Untitled"
        content = article.get("content") or ""
        markdown = f"# {title}\n\n{md(content)}" if content.strip(
        ) else f"# {title}\n\n*No content available*"
        return markdown[:max_length]
    except Exception:
        pass

    # Fallback: beautifulsoup4
    try:
        from bs4 import BeautifulSoup
        from markdownify import markdownify as md

        soup = BeautifulSoup(html, "html.parser")
        for tag in soup(["script", "style", "nav", "footer", "header"]):
            tag.decompose()
        title = soup.title.string if soup.title else "Untitled"
        body = soup.find("main") or soup.find(
            "article") or soup.find("body") or soup
        markdown = f"# {title}\n\n{md(str(body))}"
        return markdown[:max_length]
    except Exception:
        pass

    # Last resort: strip all tags manually
    import re
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text).strip()
    return text[:max_length]


def main():
    parser = argparse.ArgumentParser(
        description="Fetch and extract readable content from a URL")
    parser.add_argument("--url", required=True, help="URL to fetch")
    parser.add_argument("--timeout", type=int, default=10,
                        help="Request timeout in seconds (default: 10)")
    parser.add_argument("--max-length", type=int, default=10000,
                        help="Max output characters (default: 10000)")
    parser.add_argument("--output-file", help="Save content to this file path")
    args = parser.parse_args()

    content = fetch(args.url, args.timeout, args.max_length)

    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Saved content to {args.output_file}")
    else:
        print(content)


if __name__ == "__main__":
    main()
