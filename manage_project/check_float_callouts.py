#!/usr/bin/env python3
"""check_float_callouts.py - verify the manuscript's float call-outs.

Alzheimer's & Dementia returned ADJ-D-26-02882 in part because floats were not
"called out in ascending numerical order". The cause was structural, not a typo:
the 2026-08-25 A&D reformat moved Methods ahead of Results without reordering the
stubs in ms/fig_tbl/_pseudo_figures.qmd, so Methods forward-referenced Figure S9,
Tables S3/S6-S10 and Data S7-S8 before the lower numbers had appeared.

Two properties are checked, per counter (fig, tbl, suppfig, supptbl, suppdata):

  1. ASCENDING FIRST MENTION. Walking the assembled body in include order, the
     first mention of each float must come in numerical order.

  2. EVERY NUMBER NAMED. Each float must appear at least once as its own
     `@label` / `[-@label]`. A float that only ever sits INSIDE an en-dash range
     -- e.g. Figure S19 in "Figures S18-S20" -- renders no literal "S19" anywhere,
     and the editorial office reads that as not called out. Range endpoints are
     themselves `@label` references, so they pass; interiors do not.

Numbering comes from the BLOCK ORDER of ms/fig_tbl/_pseudo_figures.qmd, which is
what Quarto numbers the assembled manuscript from. The standalone float documents
are checked against it too, since a drift there makes the deliverables disagree
with the manuscript silently.

Usage:  python3 manage_project/check_float_callouts.py
Exit 0 if everything holds, 1 otherwise.
"""

import re
import sys
from pathlib import Path

MS = Path("ms")
PSEUDO = MS / "fig_tbl/_pseudo_figures.qmd"
ROOT_QMD = MS / "write-ms/dementia_EWAS.qmd"

# Rendered prefixes, from crossref: in ms/_metadata.yml.
PREFIX = {"fig": "Figure ", "tbl": "Table ",
          "suppfig": "Figure S", "supptbl": "Table S", "suppdata": "Data S"}

# Standalone deliverables and the counters each one owns. A counter listed here
# must appear in the named file in exactly the same order as in PSEUDO.
STANDALONE = {
    "fig": ["fig_tbl/main_figures.qmd"],
    "tbl": ["fig_tbl/main_tables.qmd"],
    "supptbl": ["fig_tbl/supplementary_tables.qmd"],
    "suppfig": ["fig_tbl/supplementary_figures.qmd"],
    "suppdata": [],          # no standalone document by design
}

DEF_RE = re.compile(r"\{#(fig|tbl|suppfig|supptbl|suppdata)-([A-Za-z0-9_-]+)")
REF_RE = re.compile(r"@(fig|tbl|suppfig|supptbl|suppdata)-([A-Za-z0-9_-]+)")
INCLUDE_RE = re.compile(r"\{\{<\s*include\s+([^\s>]+)\s*>\}\}")
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)


def definitions(path):
    """Labels in block order, as (kind, label) pairs."""
    return DEF_RE.findall(path.read_text())


def prose_files():
    """The included prose files, in the order the manuscript assembles them.

    _pseudo_figures.qmd is excluded: it defines the floats, it does not cite them.
    """
    base = ROOT_QMD.parent
    out = []
    for rel in INCLUDE_RE.findall(ROOT_QMD.read_text()):
        p = (base / rel).resolve()
        if p.name == PSEUDO.name:
            continue
        out.append(p)
    return out


def references():
    """Every cross-reference in the body, in source order, as (kind, label, where).

    HTML comments are stripped first: ms/write-ms/*.qmd carry long working-note
    blocks, and a reference quoted inside one is not a call-out.
    """
    out = []
    for p in prose_files():
        # Blank the comment out rather than delete it: keeping the newlines keeps
        # the reported line numbers the ones a person can open in the file.
        text = COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), p.read_text())
        for i, line in enumerate(text.splitlines(), 1):
            for kind, label in REF_RE.findall(line):
                out.append((kind, label, f"{p.name}:{i}"))
    return out


def main():
    if not Path("_quarto.yml").exists():
        sys.exit("error: run from the project root (where _quarto.yml lives)")

    defs = definitions(PSEUDO)
    number, order, counters = {}, {}, {}
    for kind, label in defs:
        counters[kind] = counters.get(kind, 0) + 1
        number[(kind, label)] = counters[kind]
        order.setdefault(kind, []).append(label)

    refs = references()
    problems = []

    # ---- 1. ascending first mention -------------------------------------
    first = {}
    for i, (kind, label, where) in enumerate(refs):
        if (kind, label) not in number:
            problems.append(f"{where}: @{kind}-{label} has no stub in {PSEUDO}")
            continue
        first.setdefault((kind, label), (i, where))

    high = {}
    for i, (kind, label, where) in enumerate(refs):
        if (kind, label) not in number or first[(kind, label)][0] != i:
            continue                      # unknown label, or not the FIRST mention
        n = number[(kind, label)]
        if n < high.get(kind, 0):
            problems.append(
                f"{where}: {PREFIX[kind]}{n} ({kind}-{label}) is first called out "
                f"after {PREFIX[kind]}{high[kind]} -- not ascending")
        high[kind] = max(high.get(kind, 0), n)

    # ---- 2. every number named at least once ----------------------------
    for kind in order:
        for label in order[kind]:
            if (kind, label) not in first:
                problems.append(
                    f"{PREFIX[kind]}{number[(kind, label)]} ({kind}-{label}) is never "
                    f"called out by its own number -- an en-dash range does not name "
                    f"its interior")

    # ---- 3. standalone documents in sync with the stubs -----------------
    for kind, rels in STANDALONE.items():
        for rel in rels:
            p = MS / rel
            if not p.exists():
                continue
            here = [l for k, l in definitions(p) if k == kind]
            if here and here != order.get(kind, []):
                problems.append(
                    f"{p}: {kind} block order differs from {PSEUDO}\n"
                    f"      here:  {here}\n"
                    f"      stubs: {order.get(kind, [])}")

    # ---- report ---------------------------------------------------------
    for kind in ("fig", "tbl", "suppfig", "supptbl", "suppdata"):
        n = len(order.get(kind, []))
        print(f"  {PREFIX[kind]}1..{n}: {n} float(s), "
              f"{sum(1 for l in order.get(kind, []) if (kind, l) in first)} called out")
    if problems:
        print("\nFAILED:", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    print("\nAll float call-outs are ascending and every number is named.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
