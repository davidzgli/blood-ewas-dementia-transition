#!/usr/bin/env python3
"""locate_in_docx.py - page and Editorial Manager line numbers of passages in a manuscript DOCX.

SUPERSEDED FOR THE RESPONSE LETTER on 2026-10-08: the revised manuscript DOCX now carries its own
line numbers (restarting on each page), and ms/revision/letter_locations.py reads those instead of
this fixed Editorial Manager grid. Kept for locating passages in a DOCX without line numbers.

The response letter must give "the page and line number for each specific change". Our DOCX has
page numbers but no line numbers; the reviewers' line numbers are the 1-65 margin stamps that
Editorial Manager (EM) prints on its PDF build. Those stamps are a FIXED grid, independent of the
text: on every letter-size page, stamp k sits at yMin = 38.22 + 11.3397 * (k - 1) pt (measured
on ms/submission/ADJ-D-26-02882_Sep012026.pdf, 2026-10-07). So a passage's EM line is the stamp
nearest to the vertical centre of the typeset line that holds it.

This script lays the DOCX out with LibreOffice (headless), reads every typeset line with its
coordinates (pdftotext -bbox-layout), finds each anchor phrase, and prints the page (the DOCX's
own page number = the stamped page the reviewers cite = EM PDF page + 3 at submission) and the
first and last EM line it spans. Matching ignores case, whitespace, punctuation and digits that
are superscript citation numbers glued to a word, so an anchor can be copied from the source.

LibreOffice is not Word and EM converts with its own engine, so a location can be off by a line
(rarely a page near a page break). Spot-check against EM's PDF once it is built.

Usage:
  python3 manage_project/locate_in_docx.py <file.docx> <anchors.txt>    (one anchor per line;
      a line "id<TAB>phrase" labels the result)
  python3 manage_project/locate_in_docx.py <file.docx> --phrase "some words"
  ... --pdf <file.pdf>    reuse a PDF already converted from that DOCX by LibreOffice
"""
import argparse
import html
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

EM_Y0, EM_STEP, EM_LINES = 38.22 + 3.94, 11.3397, 65   # centre of stamp 1, spacing, count


def em_line(y_centre):
    k = round((y_centre - EM_Y0) / EM_STEP) + 1
    return max(1, min(EM_LINES, k))


def norm(s):
    s = s.lower()
    s = re.sub(r"[⁰-₟¹²³]", "", s)      # unicode superscripts
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s


def layout(docx, pdf=None):
    tmp = Path(tempfile.mkdtemp(prefix="locate_"))
    if pdf is None:
        shutil.copy(docx, tmp / "doc.docx")
        subprocess.run(["soffice", "--headless", "--convert-to", "pdf", "--outdir", str(tmp),
                        str(tmp / "doc.docx")], check=True, capture_output=True)
        pdf = tmp / "doc.pdf"
    out = tmp / "doc.html"
    subprocess.run(["pdftotext", "-bbox-layout", str(pdf), str(out)], check=True)
    text = out.read_text(encoding="utf-8")
    lines = []   # (page, y_centre, normalized text)
    for pno, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", text, re.S), start=1):
        for ln in re.findall(r"<line ([^>]*)>(.*?)</line>", page, re.S):
            attrs, body = ln
            y0 = float(re.search(r'yMin="([\d.]+)"', attrs).group(1))
            y1 = float(re.search(r'yMax="([\d.]+)"', attrs).group(1))
            words = [html.unescape(w) for w in re.findall(r"<word[^>]*>([^<]*)</word>", body)]
            lines.append((pno, (y0 + y1) / 2, norm(" ".join(words)), " ".join(words)))
    return lines, pdf


def find(lines, phrase):
    target = norm(phrase)
    if not target:
        return None
    stream, owner = [], []
    for i, (_, _, t, _) in enumerate(lines):
        stream.append(t)
        owner.extend([i] * len(t))
    joined = "".join(stream)
    pos = joined.find(target)
    if pos < 0:
        return None
    if joined.find(target, pos + 1) >= 0:
        dup = True
    else:
        dup = False
    a, b = owner[pos], owner[pos + len(target) - 1]
    pa, ya = lines[a][0], lines[a][1]
    pb, yb = lines[b][0], lines[b][1]
    return pa, em_line(ya), pb, em_line(yb), dup


def fmt(hit):
    pa, la, pb, lb, dup = hit
    s = f"p. {pa}, l. {la}" if (pa, la) == (pb, lb) else (
        f"p. {pa}, ll. {la}–{lb}" if pa == pb else f"p. {pa}, l. {la} – p. {pb}, l. {lb}")
    return s + ("  [AMBIGUOUS: phrase occurs more than once]" if dup else "")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("docx")
    ap.add_argument("anchors", nargs="?")
    ap.add_argument("--phrase")
    ap.add_argument("--pdf", help="reuse this LibreOffice PDF of the DOCX instead of converting again")
    a = ap.parse_args()
    lines, pdf = layout(a.docx, a.pdf)
    print(f"# {a.docx}: {lines[-1][0]} pages (LibreOffice layout at {pdf})", file=sys.stderr)
    items = []
    if a.phrase:
        items.append(("phrase", a.phrase))
    if a.anchors:
        for raw in Path(a.anchors).read_text(encoding="utf-8").splitlines():
            if not raw.strip() or raw.startswith("#"):
                continue
            key, _, ph = raw.partition("\t")
            items.append((key, ph) if ph else (raw[:30], raw))
    bad = 0
    for key, ph in items:
        hit = find(lines, ph)
        if hit is None:
            bad += 1
            print(f"{key}\tNOT FOUND\t{ph[:80]}")
        else:
            print(f"{key}\t{fmt(hit)}\t{ph[:80]}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
