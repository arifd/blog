#!/usr/bin/env python3
"""Add a GitHub Pages project repository prefix to generated URLs.

Dodeca emits root-relative asset and page URLs (for example, ``/_/site.css``).
Those paths work on a user site served at ``https://owner.github.io/``, but on
a project site they must include the repository path, such as
``/blog/_/site.css``. Dodeca 0.17 has no documented base-path setting, so this
post-build step updates generated HTML and CSS before Pages deploys them.
"""

from pathlib import Path
import os
import re
import sys


def main() -> None:
    output_dir = Path(sys.argv[1])
    repository = os.environ["GITHUB_REPOSITORY"]
    repository_name = repository.partition("/")[2]

    # User and organization sites use the special owner.github.io repository
    # and are served from the domain root. Other repositories use /<repo>/.
    if repository_name.lower() == f"{repository.partition('/')[0]}.github.io".lower():
        return

    base_path = f"/{repository_name}"
    # Prefix HTML links and CSS url(...) references only when they start at the
    # site root. Leave protocol-relative URLs (//host/path) untouched.
    root_relative_url = re.compile(
        r'''(?P<prefix>(?:href|src|srcset|action)=["']|url\(["']?)/(?=[^/])'''
    )

    for path in output_dir.rglob("*"):
        if path.suffix.lower() not in {".html", ".css"}:
            continue

        contents = path.read_text()
        updated_contents = root_relative_url.sub(
            lambda match: f"{match.group('prefix')}{base_path}/",
            contents,
        )
        if updated_contents != contents:
            path.write_text(updated_contents)


if __name__ == "__main__":
    main()
