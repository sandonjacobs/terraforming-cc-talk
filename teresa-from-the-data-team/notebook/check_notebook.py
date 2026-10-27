"""Offline hygiene check for committed notebooks (standard library only).

Usage: python3 check_notebook.py <notebook.ipynb> [...]

Fails when a notebook is not valid notebook JSON, still holds saved outputs or execution counts,
or contains text that looks like a secret or a Confluent identifier (constitution Principle II), or
calls that write to the catalog (the notebook must stay read-only).
Problems name the cell and the rule, never the matched text.
"""

import json
import re
import sys
from pathlib import Path

# An ID needs a digit, so words like "env-file" are not flagged.
RULES = (
    ("a key, secret, or token assigned a long literal",
     re.compile(r"""(?i)(api[_-]?key|secret|password|token)\s*[=:]\s*["'][^"']{12,}["']""")),
    ("a Confluent resource ID",
     re.compile(r"(?i)\b(?:lkc|lsrc|lfcp|env|sa)-(?=[a-z0-9]*\d)[a-z0-9]{5,}\b")),
    ("an organization UUID",
     re.compile(r"(?i)\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b")),
    ("a bearer token", re.compile(r"Bearer\s+\S+")),
    # The notebook is a read-only consumer (FR-025). A write through the catalog would also need
    # permissions Teresa does not have.
    ("a call that writes to the catalog",
     re.compile(r"\.(?:create_table(?:_if_not_exists)?|create_namespace(?:_if_not_exists)?|"
                r"drop_table|drop_namespace|rename_table|register_table|purge_table|overwrite|upsert)\s*\(")),
)


def _source(cell):
    source = cell.get("source", "")
    return "".join(source) if isinstance(source, list) else str(source)


def check(path):
    try:
        notebook = json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        return [f"not readable as JSON ({type(error).__name__})"]

    if not isinstance(notebook, dict) or notebook.get("nbformat") != 4:
        return ["not a notebook: nbformat must be 4"]
    cells = notebook.get("cells")
    if not isinstance(cells, list):
        return ["not a notebook: no cells list"]

    problems = []
    for index, cell in enumerate(cells):
        if cell.get("outputs"):
            problems.append(f"cell {index}: has saved output (clear outputs before committing)")
        if cell.get("execution_count") is not None:
            problems.append(f"cell {index}: has an execution count (clear outputs before committing)")
        haystack = _source(cell) + json.dumps(cell.get("outputs", ""))
        for description, pattern in RULES:
            if pattern.search(haystack):
                problems.append(f"cell {index}: looks like it contains {description}")
    return problems


def main(paths):
    failed = False
    for path in paths:
        for problem in check(path):
            print(f"{path}: {problem}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
