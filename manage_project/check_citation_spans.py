#!/usr/bin/env python3
"""Read the collapsed citation spans back out of a render, as the revision notes require.

A collapsing CSL prints `[@RN5; @RN43; @RN42; @RN36; @RN40]` as a span (`14-18`) rather than a
list. Any renumbering -- adding a reference, or reordering the prose sections -- changes which
numbers land inside that span. This script recomputes each multi-key bracket's numbers from the
source and confirms the rendered text carries exactly that span and no other.

Usage: check_citation_spans.py <rendered.docx>

The DOCX is used rather than the PDF because pdftotext mangles superscript digits; the DOCX goes
through pandoc's citeproc with the same CSL and prints the numbers as plain text.
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
# a citation bracket: [@RN1] or [@RN1; @RN2; ...] -- not [-@fig-x], which is a float reference
BRACKET = re.compile(r"\[@RN\d+(?:\s*;\s*@RN\d+)*\]")


def sources():
    main = MAIN.read_text(encoding="utf-8")
    for rel in INCLUDE.findall(main):
        path = (MAIN.parent / rel).resolve()
        yield path, COMMENT.sub("", path.read_text(encoding="utf-8"))


def citation_order():
    order, seen = [], set()
    for _, text in sources():
        for key in KEY.findall(text):
            if key not in seen:
                seen.add(key)
                order.append(key)
    return {key: n for n, key in enumerate(order, start=1)}


def collapse(nums):
    """Render a sorted number list the way a citation-number-collapsing CSL does."""
    runs, start, prev = [], nums[0], nums[0]
    for n in nums[1:] + [None]:
        if n == prev + 1:
            prev = n
            continue
        runs.append((start, prev))
        if n is not None:
            start = prev = n
    out = []
    for lo, hi in runs:
        if hi - lo >= 2:
            out.append(f"{lo}-{hi}")          # a run of 3+ collapses to a span
        elif hi - lo == 1:
            out.extend([str(lo), str(hi)])    # a run of 2 stays a list
        else:
            out.append(str(lo))
    return ",".join(out)


def main():
    docx = Path(sys.argv[1])
    numbers = citation_order()
    rendered = subprocess.run(["pandoc", str(docx), "-t", "plain"],
                              capture_output=True, text=True, check=True).stdout
    # normalise dash variants and drop the soft line wrapping pandoc adds
    flat = re.sub(r"\s+", " ", rendered).replace("–", "-").replace("−", "-")

    problems, spans = [], 0
    for _, text in sources():
        for bracket in BRACKET.findall(text):
            keys = KEY.findall(bracket)
            if len(keys) < 2:
                continue
            nums = sorted(numbers[k] for k in keys)
            expected = collapse(nums)
            spans += 1
            if expected not in flat:
                problems.append(f"{bracket}\n      keys  -> {', '.join(keys)}"
                                f"\n      nums  -> {nums}"
                                f"\n      expect-> '{expected}'  NOT FOUND in the render")
            elif "-" in expected:
                lo, hi = (int(x) for x in re.match(r"(\d+)-(\d+)", expected).groups())
                inside = set(range(lo, hi + 1))
                claimed = {numbers[k] for k in keys}
                extra = inside - claimed
                if extra:
                    problems.append(f"{bracket}\n      span '{expected}' also swallows {sorted(extra)}")

    print(f"multi-key citation brackets checked: {spans}")
    if problems:
        print("\nFAIL")
        for p in problems:
            print("  - " + p)
        return 1
    print("OK - every span contains exactly its own bracket's references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
