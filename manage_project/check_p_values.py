#!/usr/bin/env python3
"""check_p_values.py - check how the manuscript sources write P values and correlations.

The rules are the house style for P values (since 2026-10-08), implemented in
custom_func/p_value_label.R. This checks the
text the authors write - the prose sections, the figure and table legends - not the figure
images, whose labels come from custom_func/p_value_label.R and custom_func/r_value_label.R.

1. Every exact value written "*P* = x", "*P* <= x" or "*P* >= x" has three significant figures:
   a decimal at P >= 0.01 (0.0147, 0.0500, 0.113), "m.mm × 10^−n^" below it (8.36 × 10^−4^).
   A plotted line or colour position may be a round number (*P* = 0.05, *P* = 1,
   *P* = 1.0 × 10^−8^); those are listed in ALLOWED_POSITIONS.
2. Every correlation written "*r* = x" (or after |*r*|, ≤, ≥) has two decimals and a true minus
   sign (*r* = −0.48, 0.40).
3. None of the retired forms is left: "p-value", "p value", a roman "P-value", "Padj", "P.adj",
   LaTeX math ($P, \\times), a hyphen in an exponent (10^-8^), or Unicode superscript
   exponents after "× 10" (Word may draw them from a fallback font).

Usage: python3 manage_project/check_p_values.py      (from the project root; exit 1 on a problem)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = (
    [ROOT / "ms/write-ms" / f for f in ("abstract.qmd", "introduction.qmd", "methods.qmd",
                                        "results.qmd", "discussion.qmd")]
    + sorted((ROOT / "ms/fig_tbl/_legends").glob("*.qmd"))
    + [ROOT / "ms/fig_tbl" / f for f in ("supplementary_figures.qmd", "supplementary_tables.qmd",
                                         "main_tables.qmd")]
)

# Where a P value marks a position on a plot rather than reporting a result
ALLOWED_POSITIONS = {("0.05", None), ("1", None), ("1.0", "8")}

NUMBER = r"\[?(\d+(?:\.\d+)?)\]?(?:\{\.rev\})?(?: × 10\^−(\d+(?:\.\d+)?)\^)?"
EXACT = re.compile(r"\*P\*\]?(?:\{\.rev\})? ?(=|≤|≥) ?" + NUMBER)

R_VALUE = re.compile(r"\*r\*\|? ?(?:=|≤|≥) ?\[?([−-]?\d+(?:\.\d+)?)")

RETIRED = {
    "lowercase or roman p-value": r"\bp[- ]values?\b|(?<![*\w])P-values?\b",
    "*P*-value used as a noun": r"\*P\*-values?(?! (?:filter|threshold))",
    "Padj / P.adj": r"\bPadj\b|\bP\.adj\b",
    "LaTeX math P or ×": r"\$P\b|\$\\times\$|\$1\.0 \\times",
    "hyphen in an exponent": r"10\^-\d",
    "Unicode superscript exponent": r"× 10[⁻⁰¹²³⁴⁵⁶⁷⁸⁹]",
}


def line_of(s, i):
    return s.count("\n", 0, i) + 1


def main():
    problems = []
    for f in FILES:
        s = f.read_text()
        rel = f.relative_to(ROOT)
        for m in EXACT.finditer(s):
            mant, exp = m.group(2), m.group(3)
            if (mant, exp) in ALLOWED_POSITIONS:
                continue
            if exp:
                ok = re.fullmatch(r"\d\.\d\d", mant) is not None
                why = "scientific mantissa must be m.mm"
            else:
                value = float(mant)
                ok = value >= 0.01 and len(mant.replace(".", "").lstrip("0")) == 3
                why = "below 0.01 must be scientific" if value < 0.01 else "needs 3 significant figures"
            if not ok:
                problems.append(f"{rel}:{line_of(s, m.start())}: {why}: {m.group(0)!r}")
        for m in R_VALUE.finditer(s):
            if re.fullmatch(r"−?\d\.\d\d", m.group(1)) is None:
                problems.append(f"{rel}:{line_of(s, m.start())}: r needs two decimals and a true minus: {m.group(0)!r}")
        for label, pattern in RETIRED.items():
            for m in re.finditer(pattern, s):
                problems.append(f"{rel}:{line_of(s, m.start())}: {label}: {s[m.start():m.end() + 15]!r}")
    for p in problems:
        print(p)
    print(f"{len(FILES)} files checked; {len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
