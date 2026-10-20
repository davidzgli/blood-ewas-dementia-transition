#!/usr/bin/env python3
"""export_figures.py - emit each main figure as its own submission file.

Alzheimer's & Dementia returned ADJ-D-26-02882 asking for "each of your figures as
separate individual files in TIFF, JPG, PDF, or EPS format (minimum resolution
300 dpi)". The manuscript's figures were going up as one 30 MB combined PDF, and
the sources are PNG -- which is not on that list -- so this script rewraps them.

The RESOLUTION was never the problem: every source is 600 dpi (one supplementary
figure is 300). Only the container was wrong. So this rewraps rather than
re-renders: a PDF page exactly the figure's physical size, holding the original
pixels at their original density. Re-running the plotting pipelines to get vector
PDFs would change the figures themselves, which is not what was asked for.

Paths are DERIVED from ms/fig_tbl/main_figures.qmd, in its block order, so the
figure numbering here cannot drift from the manuscript's. Nothing is hardcoded --
that is the same rule ms/post_process_pdf.sh follows for the title and font, after
a hardcoded copy there shipped the retired Nature title for three days.

Usage: python3 ms/export_figures.py [--out-dir DIR]
  --out-dir DIR   where to write (default: ms/submission/figures, the as-submitted set)
  e.g.  python3 ms/export_figures.py --out-dir ms/revision/figures
Outputs: <out-dir>/Figure1.pdf .. Figure6.pdf
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image

SRC_QMD = Path("ms/fig_tbl/main_figures.qmd")
# Default output directory: the as-submitted figures. Overridden by --out-dir.
DEFAULT_OUT_DIR = Path("ms/submission/figures")
MIN_DPI = 300

GREEN, RED, YELLOW, NC = "\033[0;32m", "\033[0;31m", "\033[1;33m", "\033[0m"

# Quarto resolves a leading "/" in an image path against the project root.
IMG_RE = re.compile(r"^!\[\]\((/[^)]+\.png)\)\{#(fig-[A-Za-z0-9_-]+)", re.M)


def figures():
    """(label, path) for each main figure, in the order main_figures.qmd defines them."""
    hits = IMG_RE.findall(SRC_QMD.read_text())
    if not hits:
        sys.exit(f"{RED}error: no figure blocks found in {SRC_QMD}{NC}")
    return [(label, Path(p.lstrip("/"))) for p, label in hits]


def pdf_page_size(path):
    """(width_pt, height_pt) of page 1, read back from the written file."""
    out = subprocess.run(["pdfinfo", str(path)], capture_output=True, text=True).stdout
    m = re.search(r"^Page size:\s+([\d.]+) x ([\d.]+) pts", out, re.M)
    if not m:
        return None
    return float(m.group(1)), float(m.group(2))


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="python3 ms/export_figures.py",
        # No prefix matching: '--out' must be an error, not a silent --out-dir.
        allow_abbrev=False,
        description="Emit each main figure as its own submission PDF "
                    "(run from the project root).")
    p.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR, metavar="DIR",
                   help=f"output directory (default: {DEFAULT_OUT_DIR})")
    args = p.parse_args(argv)
    if not str(args.out_dir).strip() or str(args.out_dir) == ".":
        p.error("--out-dir must name a directory (an empty value would write into the project root)")
    return args


def main(argv=None):
    args = parse_args(argv)
    if not Path("_quarto.yml").exists():
        sys.exit(f"{RED}error: run from the project root (where _quarto.yml lives){NC}")

    out_dir = args.out_dir
    figs = figures()
    out_dir.mkdir(parents=True, exist_ok=True)
    print("=" * 40)
    print("Submission figure export")
    print("=" * 40)
    print(f"{len(figs)} figure(s) from {SRC_QMD}\n")

    failed = 0
    for i, (label, src) in enumerate(figs, 1):
        out = out_dir / f"Figure{i}.pdf"
        print(f"{YELLOW}[{i}] {label}{NC}\n    <- {src}")
        if not src.exists():
            print(f"{RED}    ERROR: missing source{NC}", file=sys.stderr)
            failed += 1
            continue

        im = Image.open(src)
        dpi = im.info.get("dpi")
        if not dpi or round(dpi[0]) != round(dpi[1]):
            print(f"{RED}    ERROR: no square dpi in the PNG ({dpi}); refusing to guess{NC}",
                  file=sys.stderr)
            failed += 1
            continue
        d = round(dpi[0])
        if d < MIN_DPI:
            print(f"{RED}    ERROR: {d} dpi is below the journal's {MIN_DPI} dpi minimum{NC}",
                  file=sys.stderr)
            failed += 1
            continue

        w_in, h_in = im.width / d, im.height / d
        # PDF has no alpha channel for a plain image page; flatten onto white so a
        # transparent PNG background does not come out black in the reader.
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            flat = Image.new("RGB", im.size, "white")
            flat.paste(im, mask=im.split()[-1])
            im = flat
        elif im.mode != "RGB":
            im = im.convert("RGB")
        im.save(out, "PDF", resolution=float(d))

        # Read the geometry back out rather than trusting the write: a wrong
        # resolution silently produces a correct-looking picture on a wrong-sized
        # page, which is exactly what a production department rejects.
        size = pdf_page_size(out)
        if size is None:
            print(f"{RED}    ERROR: pdfinfo could not read {out}{NC}", file=sys.stderr)
            failed += 1
            continue
        want = (w_in * 72, h_in * 72)
        if max(abs(size[0] - want[0]), abs(size[1] - want[1])) > 1.0:
            print(f"{RED}    ERROR: page is {size[0]:.0f}x{size[1]:.0f} pt, "
                  f"expected {want[0]:.0f}x{want[1]:.0f} pt{NC}", file=sys.stderr)
            failed += 1
            continue

        print(f"    -> {out}")
        print(f"       {im.width} x {im.height} px @ {d} dpi = "
              f"{w_in:.2f} x {h_in:.2f} in ({size[0]:.0f} x {size[1]:.0f} pt), "
              f"{out.stat().st_size // 1024} KB")
        print(f"{GREEN}    Done{NC}")

    print("\n" + "=" * 40)
    if failed:
        print(f"{RED}{failed} of {len(figs)} figure(s) failed{NC}")
        return 1
    print(f"{GREEN}All {len(figs)} figures exported{NC}\n\nOutput location:\n  - {out_dir}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
