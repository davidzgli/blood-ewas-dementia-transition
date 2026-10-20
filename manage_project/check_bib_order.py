#!/usr/bin/env python3
"""Verify the rendered bibliography against the expected citation order.

Expected order = first appearance of each @RN key, scanning ms/write-ms/dementia_EWAS.qmd's
{{< include >}} children in the order it includes them. Both Nature and AMA CSLs number by
citation order, so this order is CSL-independent; only the entry formatting changes.

Usage: check_bib_order.py <rendered.pdf>
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "ms/write-ms/dementia_EWAS.qmd"

COMMENT = re.compile(r"<!--.*?-->", re.S)
INCLUDE = re.compile(r"\{\{<\s*include\s+(\S+?)\s*>\}\}")
KEY = re.compile(r"@(RN\d+)")


def source_order():
    main = MAIN.read_text(encoding="utf-8")
    order, seen = [], set()
    for rel in INCLUDE.findall(main):
        text = (MAIN.parent / rel).resolve().read_text(encoding="utf-8")
        for key in KEY.findall(COMMENT.sub("", text)):
            if key not in seen:
                seen.add(key)
                order.append(key)
    return order


def bib_index():
    """key -> (first-author surname, year), read straight from the source-of-truth bib."""
    raw = (ROOT / "ms/reference/dementia-EWAS.bib").read_text(encoding="utf-8-sig")
    entries = {}
    for block in re.split(r"\n(?=@)", raw):
        m = re.match(r"@\w+\{(RN\d+),", block)
        if not m:
            continue
        author = re.search(r"^\s*author\s*=\s*\{(.+?)\}\s*,?\s*$", block, re.M | re.S)
        year = re.search(r"^\s*year\s*=\s*\{(\d{4})\}", block, re.M)
        surname = ""
        if author:
            surname = author.group(1).split(" and ")[0].split(",")[0].strip()
            surname = surname.split()[-1] if surname else ""
        entries[m.group(1)] = (surname, year.group(1) if year else "")
    return entries


def rendered_entries(pdf):
    text = subprocess.run(
        ["pdftotext", "-layout", str(pdf), "-"],
        capture_output=True, text=True, check=True).stdout
    # Typst stamps a per-page line number in the margin: "<lineno>   <content>"
    lines = [re.sub(r"^\s*\d+\s{2,}", "", ln) for ln in text.splitlines()]
    start = max(i for i, ln in enumerate(lines) if ln.strip() == "Bibliography")
    out, current = {}, None
    for ln in lines[start + 1:]:
        m = re.match(r"\s*(\d{1,3})\.\s+(.*)", ln)
        if m and (current is None or int(m.group(1)) == current + 1):
            current = int(m.group(1))
            out[current] = m.group(2)
        elif current is not None:
            out[current] += " " + ln.strip()
    return out


def main():
    pdf = Path(sys.argv[1])
    order, bib, rendered = source_order(), bib_index(), rendered_entries(pdf)

    print(f"cited keys in source : {len(order)}")
    print(f"entries rendered     : {len(rendered)} (max #{max(rendered)})")

    problems = []
    if len(rendered) != len(order):
        problems.append(f"count mismatch: {len(rendered)} rendered vs {len(order)} cited")

    for n, key in enumerate(order, start=1):
        surname, year = bib.get(key, ("", ""))
        body = rendered.get(n, "")
        if not surname:
            problems.append(f"#{n} {key}: no author in bib")
        elif surname.split("-")[0] not in body:
            problems.append(f"#{n} {key}: expected '{surname}' ({year}), got: {body[:70]}")

    missing_doi = [k for k in order if k not in bib or not re.search(
        r"^\s*DOI\s*=", (ROOT / "ms/reference/dementia-EWAS.bib").read_text(
            encoding="utf-8-sig").split(f"@article{{{k},")[-1].split("\n@")[0], re.M)]

    print(f"malformed DOI fields : "
          f"{sum(1 for ln in (ROOT / 'ms/reference/dementia-EWAS.bib').read_text(encoding='utf-8-sig').splitlines() if re.match(r'\s*DOI\s*=\s*\{https?://', ln))}")
    print(f"cited keys with no DOI: {len(missing_doi)} {missing_doi}")

    if problems:
        print("\nFAIL")
        for p in problems:
            print("  " + p)
        return 1
    print("\nOK - every bibliography number matches its expected key")
    return 0


if __name__ == "__main__":
    sys.exit(main())
