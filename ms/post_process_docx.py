#!/usr/bin/env python3
"""post_process_docx.py - Assemble journal-submission DOCX files from the rendered outputs.

The Word counterpart to ms/post_process_pdf.sh. Takes the .docx produced by ms/render.sh
and, for each one:

  - drops Quarto's auto table of contents (the "Contents" heading lives inside the same
    <w:sdt> block, so one deletion removes both)
  - drops the build timestamp paragraph (style "Date"), keeping the document title
  - drops the pseudo-figure placeholder blocks that exist only so cross-references resolve

Handles two documents (A&D wants figures as separate image files, not embedded in Word):

  ms/write-ms/dementia_EWAS.docx  ->  <out-dir>/dementia_EWAS<suffix>.docx   (job "manuscript")
  ms/fig_tbl/main_tables.docx     ->  <out-dir>/main_tables<suffix>.docx     (job "main_tables")

(main_tables was ms/fig_tbl/table1.qmd / table1.docx until 2026-10-08; the as-submitted
ms/submission/table1.docx keeps the old name.)

With --line-numbers, the manuscript also gets Word line numbering that restarts at 1 on
every page (<w:lnNumType w:countBy="1" w:restart="newPage"/> in every section), so the
response to reviewers can cite page and line of the file itself (revision builds only).

Outputs go to ms/submission/ by default, under the input's own name -- exactly the
as-submitted behaviour. A revision build passes --out-dir ms/revision and a --suffix
(_clean / _marked, one build per revision-markup mode) so the submitted files are never
overwritten. Source files are never modified.

WHY THIS IS PYTHON AND NOT A .sh LIKE ITS PDF SIBLING. The work is XML surgery inside a
zip container. A line-based sed/awk filter over wrapped XML is the failure mode already
recorded in the project notes for the public-release exporter, where a line-wise edit
deleted the line carrying a matched word and stranded its neighbours -- and that shipped.
lxml removes whole elements or nothing.

THE TRAP THIS SCRIPT EXISTS TO AVOID. The 49 placeholder blocks are NOT at the end of the
manuscript. They sit between the Disclosure section and the references (paragraphs 153-295
of 364 at the time of writing), so "delete from the first placeholder to the end of the
body" silently eats all 68 bibliography entries. Nothing about the rendered file advertises
this; you only see it by walking the paragraph list. The range is therefore detected and
bounded at both ends, and the run asserts the bibliography survives.

Like ms/post_process_pdf.sh, everything is DETECTED rather than hardcoded, so a re-render
that changes the float list or the section order cannot leave a stale block behind. Every
check is fail-loud: this script would rather refuse to write than write something subtly
wrong into a submission.

Usage (from the project root):
  python3 ms/post_process_docx.py [--out-dir DIR] [--suffix STR] [--only {manuscript,main_tables}]
                                   [--line-numbers]

  --out-dir DIR   where to write (default: ms/submission)
  --suffix STR    appended to each output's stem: dementia_EWAS<STR>.docx (default: none)
  --only JOB      assemble one document instead of both (default: both)
  --line-numbers  number the manuscript's lines, restarting on each page (default: off)

  e.g.  python3 ms/post_process_docx.py --out-dir ms/revision --suffix _marked
"""

import argparse
import re
import shutil
import sys
import zipfile
from pathlib import Path

try:
    from lxml import etree
except ImportError:  # pragma: no cover
    sys.exit("error: lxml is required (pip install lxml)")

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"w": W, "r": R}

DOC_XML = "word/document.xml"
RELS_XML = "word/_rels/document.xml.rels"
TYPES_XML = "[Content_Types].xml"
FOOTER_XML = "word/footer1.xml"

REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
FOOTER_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer"
FOOTER_CT = ("application/vnd.openxmlformats-officedocument"
             ".wordprocessingml.footer+xml")

# A centred PAGE field. Word computes the number itself, so the file stays correct when the
# editor's copy repaginates -- unlike the PDF bundle, where ms/post_process_pdf.sh has to
# stamp literal numbers over the old ones because a PDF has no such field.
FOOTER_DOC = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="{W}" xmlns:r="{R}">
  <w:p>
    <w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:fldChar w:fldCharType="begin"/></w:r>
    <w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>
    <w:r><w:fldChar w:fldCharType="separate"/></w:r>
    <w:r><w:t>1</w:t></w:r>
    <w:r><w:fldChar w:fldCharType="end"/></w:r>
  </w:p>
</w:ftr>'''.encode("utf-8")

# Default output directory: the as-submitted files. Overridden by --out-dir.
DEFAULT_OUT_DIR = Path("ms/submission")
PSEUDO = Path("ms/fig_tbl/_pseudo_figures.qmd")

# (job name, rendered input, strip the pseudo-figure placeholders?)
JOBS = [("manuscript", "ms/write-ms/dementia_EWAS.docx", True),
        ("main_tables", "ms/fig_tbl/main_tables.docx", False)]

# Float labels as RENDERED, matching ms/post_process_pdf.sh's PLACEHOLDER_RE. Word uses a
# NON-BREAKING space between the word and the number ("Figure\xa01"), which an ordinary
# \s in a hand-written pattern does happen to match -- but only because \s covers \xa0 in
# Python's str mode. Spelled out here so the next person does not "simplify" it to " ".
FLOAT_LABEL = re.compile(r"^(Figure|Table|Data)[\s ]+S?\d+$")

GREEN, RED, YELLOW, NC = "\033[0;32m", "\033[0;31m", "\033[1;33m", "\033[0m"


class Abort(Exception):
    """A guard failed. The output file is not written."""


# ---------------------------------------------------------------- helpers


def element_text(el):
    """Visible text anywhere inside an element, joined in document order."""
    return "".join(t.text or "" for t in el.iterfind(f".//{{{W}}}t"))


def para_text(p):
    """Visible text of a <w:p>, joined across runs."""
    return element_text(p)


def para_style(p):
    s = p.find("./w:pPr/w:pStyle", NS)
    return s.get(f"{{{W}}}val") if s is not None else None


def body_children(root):
    """Direct children of <w:body>, in document order.

    Deliberately not .//w:p. A pseudo-figure placeholder is not a paragraph: Quarto emits
    each one as a whole <w:tbl> holding the image and its caption in one cell, so a
    paragraph-level scan finds ZERO drawings and reports success having deleted nothing.
    That is precisely what the first version of this script did.
    """
    body = root.find("./w:body", NS)
    if body is None:
        raise Abort("no <w:body> in document.xml")
    return list(body)


def body_paragraphs(root):
    """Top-level <w:p> children of <w:body>."""
    return [el for el in body_children(root) if el.tag == f"{{{W}}}p"]


def drop(el):
    el.getparent().remove(el)


def expected_float_count():
    """Number of floats declared in _pseudo_figures.qmd -- the placeholder count to expect."""
    if not PSEUDO.exists():
        raise Abort(f"missing {PSEUDO}")
    return len(re.findall(r"\{#(?:fig|tbl|suppfig|supptbl|suppdata)-[A-Za-z0-9_-]+\}",
                          PSEUDO.read_text(encoding="utf-8")))


# ---------------------------------------------------------------- operations


def find_overview(root):
    """The "Overview" heading and its body, for the float documents.

    Internal orientation text ("This document compiles main and supplementary tables...")
    that has no place in a submission. Bounded by the next structural sibling -- a heading,
    a table, or a page-break paragraph -- never by a fixed paragraph count.
    """
    kids = body_children(root)
    start = None
    for i, el in enumerate(kids):
        if el.tag == f"{{{W}}}p" and (para_style(el) or "").startswith("Heading") \
                and element_text(el).strip() == "Overview":
            start = i
            break
    if start is None:
        return []
    out = [kids[start]]
    for el in kids[start + 1:]:
        if el.tag != f"{{{W}}}p":
            break
        if (para_style(el) or "").startswith("Heading"):
            break
        if el.find(f'.//{{{W}}}br[@{{{W}}}type="page"]') is not None:
            break
        out.append(el)
    return out


def find_float_captions(root):
    """The auto-generated bare-label caption inside each float wrapper.

    Quarto turns `![](x.png){#tbl-y}` into a <w:tbl> holding the image and an ImageCaption
    paragraph whose entire text is the rendered label -- "Table S1" and nothing else. Every
    float here is followed by a hand-written legend that already opens with the same label
    ("Table S1 | Covariate characteristics ..."), so the caption is a redundant line.

    Position differs by float kind and is NOT a reliable way to find them: Quarto puts the
    main table's caption ABOVE its image and every supplementary caption BELOW. Matched on
    style plus an exact float-label match instead, so a caption carrying real text is never
    removed.

    Not fixable in the source: the {#tbl-...} id is what generates both the caption and the
    cross-reference target, and float numbering is the most fragile thing in this tree.

    The wrapper is matched on being a top-level <w:tbl>, NOT on containing a <w:drawing>.
    Since 2026-08-31 Table 1 is a NATIVE Word table (ms/fig_tbl/main_tables.qmd, for A&D's
    "editable text format" requirement), so its wrapper holds no image at all -- the older
    drawing test silently skipped it and the bare "Table 1" line printed twice.
    """
    out = []
    for tbl in body_children(root):
        if tbl.tag != f"{{{W}}}tbl":
            continue
        for p in tbl.iterfind(f".//{{{W}}}p"):
            if para_style(p) == "ImageCaption" and FLOAT_LABEL.match(element_text(p).strip()):
                out.append(p)
    return out


def text_excluding(el, removed_ids):
    """element_text(el), ignoring text inside paragraphs scheduled for deletion."""
    parts = []
    for t in el.iterfind(f".//{{{W}}}t"):
        node, skip = t, False
        while node is not None:
            if id(node) in removed_ids:
                skip = True
                break
            node = node.getparent()
        if not skip:
            parts.append(t.text or "")
    return "".join(parts)


def add_page_numbers(parts):
    """Attach a centred PAGE-field footer to the document's section.

    Four coordinated edits -- the footer part, its relationship, its content-type override,
    and a <w:footerReference> in <w:sectPr>. Omit any one and Word either ignores the footer
    or reports the file as corrupt. The reference must be the FIRST child of sectPr: the
    schema puts header/footer references ahead of pgSz and pgMar, and Word rejects the file
    if they appear after.
    """
    root = etree.fromstring(parts[DOC_XML])
    sect = root.find("./w:body/w:sectPr", NS)
    if sect is None:
        raise Abort("no <w:sectPr> -- cannot attach a footer")
    if sect.find("./w:footerReference", NS) is not None:
        return parts, False
    # Since 2026-10-07 main_tables.docx has TWO sections (Table 1 portrait, Table 2 landscape):
    # a section break is a <w:sectPr> inside the <w:pPr> of the paragraph that ends the
    # section. A section with no footerReference has no footer at all when it is the first
    # one (Word inherits only from a PREVIOUS section), so every section gets the reference.
    inline = root.findall(".//w:body/w:p/w:pPr/w:sectPr", NS)

    rels = etree.fromstring(parts[RELS_XML])
    used = {r.get("Id") for r in rels}
    rid = next(f"rId{n}" for n in range(900, 999) if f"rId{n}" not in used)
    etree.SubElement(rels, f"{{{REL_NS}}}Relationship",
                     Id=rid, Type=FOOTER_REL, Target="footer1.xml")

    for s in [sect, *inline]:
        ref = etree.Element(f"{{{W}}}footerReference")
        ref.set(f"{{{W}}}type", "default")
        ref.set(f"{{{R}}}id", rid)
        s.insert(0, ref)

    types = etree.fromstring(parts[TYPES_XML])
    if not any(o.get("PartName") == "/" + FOOTER_XML for o in types):
        etree.SubElement(types, f"{{{CT_NS}}}Override",
                         PartName="/" + FOOTER_XML, ContentType=FOOTER_CT)

    parts[DOC_XML] = etree.tostring(root, xml_declaration=True,
                                    encoding="UTF-8", standalone=True)
    parts[RELS_XML] = etree.tostring(rels, xml_declaration=True,
                                     encoding="UTF-8", standalone=True)
    parts[TYPES_XML] = etree.tostring(types, xml_declaration=True,
                                      encoding="UTF-8", standalone=True)
    parts[FOOTER_XML] = FOOTER_DOC
    return parts, True


# Children of <w:sectPr> that the schema (CT_SectPr) places AFTER <w:lnNumType>. Word
# rejects a file whose sectPr children are out of order, so the element is inserted before
# the first of these, or appended when none is present.
AFTER_LNNUM = {"pgNumType", "cols", "formProt", "vAlign", "noEndnote", "titlePg",
               "textDirection", "bidi", "rtlGutter", "docGrid", "printerSettings",
               "sectPrChange"}


def add_line_numbers(parts):
    """Number every line, restarting at 1 on each page, in every section of the document.

    Word draws the numbers in the left margin of the body text; table rows, headers and
    footers are not counted. LibreOffice honours the same element, which is how the
    response to reviewers reads page and line locations from the file
    (ms/revision/letter_locations.py).
    """
    root = etree.fromstring(parts[DOC_XML])
    sects = root.findall("./w:body/w:sectPr", NS) + root.findall(".//w:body/w:p/w:pPr/w:sectPr", NS)
    if not sects:
        raise Abort("no <w:sectPr> -- cannot add line numbering")
    for s in sects:
        if s.find("./w:lnNumType", NS) is not None:
            continue
        ln = etree.Element(f"{{{W}}}lnNumType")
        ln.set(f"{{{W}}}countBy", "1")
        ln.set(f"{{{W}}}restart", "newPage")
        after = next((c for c in s if etree.QName(c).localname in AFTER_LNNUM), None)
        if after is None:
            s.append(ln)
        else:
            after.addprevious(ln)
    parts[DOC_XML] = etree.tostring(root, xml_declaration=True,
                                    encoding="UTF-8", standalone=True)
    return parts, len(sects)


def find_toc(root):
    """The <w:sdt> whose field instruction is a TOC, or None.

    Returned rather than deleted in place: it is itself a <w:body> child, so the
    prose invariant has to know it was removed on purpose.
    """
    for sdt in root.iterfind(".//w:sdt", NS):
        instr = "".join(i.text or "" for i in sdt.iterfind(".//w:instrText", NS))
        if "TOC" in instr:
            return sdt
    return None


def find_timestamp(root):
    """Paragraphs styled "Date" -- Quarto's build stamp."""
    return [p for p in body_paragraphs(root) if para_style(p) == "Date"]


def find_placeholder_range(root, expected):
    """Locate the placeholder run and return (elements_to_delete, labels).

    A placeholder is a <w:tbl> child of <w:body> containing a <w:drawing>; its float-label
    caption lives inside the same table. Between consecutive placeholders Quarto emits a
    whitespace-only <w:p> spacer, and one blank paragraph precedes the run.

    The run is bounded at BOTH ends. It does not reach the end of the body: the bibliography
    follows it, and two <w:bookmarkStart> elements sit in between. Deleting to the end of the
    body -- the obvious implementation -- silently destroys all 68 references.
    """
    kids = body_children(root)
    tbl = f"{{{W}}}tbl"
    placeholders = [i for i, el in enumerate(kids)
                    if el.tag == tbl and el.find(f".//{{{W}}}drawing") is not None]
    if not placeholders:
        raise Abort("no placeholder tables found -- has the render output changed shape?")

    if len(placeholders) != expected:
        raise Abort(
            f"expected {expected} placeholder blocks (from {PSEUDO}), found {len(placeholders)}. "
            "Refusing to guess which are real content."
        )
    other_tables = [i for i, el in enumerate(kids)
                    if el.tag == tbl and i not in set(placeholders)]
    if other_tables:
        raise Abort(
            f"{len(other_tables)} table(s) in the body are not placeholders "
            f"(body indices {other_tables[:5]}). Refusing to delete a range containing them."
        )

    lo, hi = placeholders[0], placeholders[-1]
    labels = []
    for i in placeholders:
        text = element_text(kids[i]).strip()
        if not FLOAT_LABEL.match(text):
            raise Abort(f"placeholder table at body index {i} has no float label: {text[:60]!r}")
        labels.append(text)

    # Everything between the first and last placeholder must be a placeholder or a blank
    # spacer -- otherwise real content sits inside the range and we must not delete it.
    kill = set(placeholders)
    for i in range(lo, hi + 1):
        if i in kill:
            continue
        el = kids[i]
        if el.tag == f"{{{W}}}p" and not element_text(el).strip():
            kill.add(i)
        else:
            raise Abort(
                f"unexpected content inside the placeholder run at body index {i}: "
                f"<{etree.QName(el).localname}> {element_text(el)[:50]!r}"
            )

    # absorb blank paragraphs immediately preceding the run
    i = lo - 1
    while i >= 0 and kids[i].tag == f"{{{W}}}p" and not element_text(kids[i]).strip():
        kill.add(i)
        i -= 1

    return [kids[i] for i in sorted(kill)], labels


def strip_orphan_media(zin_names, doc_xml, rels_xml):
    """Drop media parts no longer referenced, and their relationship entries.

    Returns (surviving_names, new_rels_bytes, dropped).
    """
    rels = etree.fromstring(rels_xml)
    rns = {"pr": "http://schemas.openxmlformats.org/package/2006/relationships"}
    used = set(re.findall(rb'r:(?:embed|id|link)="([^"]+)"', doc_xml))
    used = {u.decode() for u in used}

    dropped_targets, dropped_ids = [], []
    for rel in list(rels.iterfind("./pr:Relationship", rns)):
        rid, target = rel.get("Id"), rel.get("Target") or ""
        if target.startswith("media/") and rid not in used:
            dropped_targets.append("word/" + target)
            dropped_ids.append(rid)
            rels.remove(rel)

    survivors = [n for n in zin_names if n not in set(dropped_targets)]
    return survivors, etree.tostring(rels, xml_declaration=True,
                                     encoding="UTF-8", standalone=True), dropped_targets


# ---------------------------------------------------------------- driver


def assemble(src, strip_placeholders, out_dir=DEFAULT_OUT_DIR, suffix="", line_numbers=False):
    src = Path(src)
    out = Path(out_dir) / f"{src.stem}{suffix}{src.suffix}"
    print(f"{YELLOW}Assembling:{NC} {src.name}")

    if not src.exists():
        raise Abort(f"missing input: {src} (run ms/render.sh first)")
    # --out-dir/--suffix make it possible to aim the output at the input itself
    # (e.g. --out-dir ms/write-ms with no suffix). Refuse: sources are never modified.
    if out.resolve() == src.resolve():
        raise Abort(f"output {out} would overwrite its own input")

    with zipfile.ZipFile(src) as z:
        names = z.namelist()
        parts = {n: z.read(n) for n in names}

    root = etree.fromstring(parts[DOC_XML])

    # Collect every deletion BEFORE applying any, so the surviving text can be predicted
    # positionally. Comparing by text value instead would be wrong twice over: identical
    # strings recur (the " " spacers), and a check that filters by pattern silently excuses
    # whatever else the run happened to remove -- which is exactly how the first version of
    # this guard passed a file it should have rejected.
    kids = body_children(root)
    before = [element_text(el) for el in kids]
    position = {id(el): i for i, el in enumerate(kids)}

    toc = find_toc(root)
    if toc is None:
        raise Abort("no TOC field found -- has the render config changed?")
    victims = [toc]

    dates = find_timestamp(root)
    n_date = len(dates)
    victims += dates

    overview = [] if strip_placeholders else find_overview(root)
    victims += overview

    # Removed from INSIDE a surviving <w:tbl>, so these change a body child's text rather
    # than removing the child. The invariant below has to account for them separately.
    captions = [] if strip_placeholders else find_float_captions(root)
    caption_ids = {id(p) for p in captions}

    labels = []
    if strip_placeholders:
        ph, labels = find_placeholder_range(root, expected_float_count())
        victims += ph
    n_ph = len(victims) - n_date - 1 - len(overview)

    deleted = {position[id(el)] for el in victims}
    expected = [text_excluding(el, caption_ids)
                for i, el in enumerate(kids) if i not in deleted]

    for el in victims + captions:
        drop(el)
    n_toc = 1

    parts[DOC_XML] = etree.tostring(root, xml_declaration=True,
                                    encoding="UTF-8", standalone=True)

    survivors, parts[RELS_XML], dropped = strip_orphan_media(
        names, parts[DOC_XML], parts[RELS_XML])

    parts, footered = add_page_numbers(parts)
    if footered and FOOTER_XML not in survivors:
        survivors.append(FOOTER_XML)

    n_numbered = 0
    if line_numbers:
        parts, n_numbered = add_line_numbers(parts)

    # ---- invariant: prose is untouched. Surviving paragraph text, in order, must equal the
    # input minus exactly the paragraphs this run chose to delete.
    after = [element_text(el) for el in body_children(etree.fromstring(parts[DOC_XML]))]
    if [t for t in after if t.strip()] != [t for t in expected if t.strip()]:
        raise Abort("prose changed during processing -- refusing to write")

    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for n in survivors:
            z.writestr(n, parts[n])

    verify(out, labels, strip_placeholders, line_numbers)

    print(f"    removed: {n_toc} TOC, {n_date} timestamp, {len(overview)} Overview,"
          f" {n_ph} placeholder paragraphs ({len(labels)} floats)")
    print(f"    removed {len(captions)} redundant float-label captions")
    print(f"    page-number footer: {'added' if footered else 'already present'}")
    if line_numbers:
        print(f"    line numbering (restart each page): {n_numbered} section(s)")
    if dropped:
        print(f"    dropped orphaned media: {', '.join(dropped)}")
    print(f"    {src.stat().st_size // 1024} KB -> {out.stat().st_size // 1024} KB")
    print(f"{GREEN}    Done{NC} {out}")
    return out


def verify(out, labels, strip_placeholders, line_numbers=False):
    """Re-open the written file and prove the things that matter are true."""
    with zipfile.ZipFile(out) as z:
        doc = z.read(DOC_XML)
        root = etree.fromstring(doc)
    problems = []
    if b"TOC" in doc and root.find(".//w:sdt", NS) is not None:
        for sdt in root.iterfind(".//w:sdt", NS):
            if "TOC" in "".join(i.text or "" for i in sdt.iterfind(".//w:instrText", NS)):
                problems.append("a TOC field survived")
    # NOT `if labels:` -- gating the checks on what the run claims to have removed lets a
    # run that removed nothing verify clean. Gate on what was ASKED for.
    if strip_placeholders:
        if root.find(f".//{{{W}}}drawing") is not None:
            problems.append("a drawing survived")
        stray = [element_text(el).strip() for el in body_children(root)
                 if FLOAT_LABEL.match(element_text(el).strip())]
        if stray:
            problems.append(f"float-label paragraphs survived: {stray[:5]}")
        bib = [p for p in body_paragraphs(root) if para_style(p) == "Bibliography"]
        if not bib:
            problems.append("the bibliography did not survive -- the placeholder range overran")
        else:
            print(f"    bibliography intact: {len(bib)} entries")
    for p in body_paragraphs(root):
        if para_style(p) == "Date":
            problems.append("the build timestamp survived")
            break
    if any(element_text(p).strip() == "Overview" for p in body_paragraphs(root)):
        if not strip_placeholders:
            problems.append("the Overview section survived")
    if not strip_placeholders:
        left = find_float_captions(root)
        if left:
            problems.append(f"{len(left)} float-label captions survived")
        legends = [p for p in body_paragraphs(root)
                   if re.match(r"^(Figure|Table|Data)[\s\u00a0]S?\d+[\s\u00a0]*\|",
                               element_text(p).strip())]
        print(f"    legends intact: {len(legends)}")
    with zipfile.ZipFile(out) as z:
        names = z.namelist()
        if FOOTER_XML not in names:
            problems.append("no footer part")
        elif b"PAGE" not in z.read(FOOTER_XML):
            problems.append("footer has no PAGE field")
        if f'"/{FOOTER_XML}"' not in z.read(TYPES_XML).decode():
            problems.append("footer missing from [Content_Types].xml")
        if b"footer1.xml" not in z.read(RELS_XML):
            problems.append("footer relationship missing")
    if root.find("./w:body/w:sectPr/w:footerReference", NS) is None:
        problems.append("sectPr has no footerReference")
    for s in root.findall(".//w:body/w:p/w:pPr/w:sectPr", NS):
        if s.find("./w:footerReference", NS) is None:
            problems.append("a section break (inline sectPr) has no footerReference")
            break
    if line_numbers:
        sects = root.findall("./w:body/w:sectPr", NS) + root.findall(".//w:body/w:p/w:pPr/w:sectPr", NS)
        for s in sects:
            ln = s.find("./w:lnNumType", NS)
            if ln is None or ln.get(f"{{{W}}}restart") != "newPage":
                problems.append("a section has no per-page line numbering")
                break
    if problems:
        raise Abort("; ".join(problems))


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="python3 ms/post_process_docx.py",
        # No prefix matching: '--out' must be an error, not a silent --out-dir.
        allow_abbrev=False,
        description="Assemble journal-submission DOCX files from the rendered outputs "
                    "(run from the project root).")
    p.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR, metavar="DIR",
                   help=f"output directory (default: {DEFAULT_OUT_DIR})")
    p.add_argument("--suffix", default="", metavar="STR",
                   help="appended to each output's stem, e.g. _clean -> "
                        "dementia_EWAS_clean.docx (default: none)")
    p.add_argument("--only", choices=[name for name, _, _ in JOBS],
                   help="assemble only this document (default: all)")
    p.add_argument("--line-numbers", action="store_true",
                   help="number the manuscript's lines, restarting on each page "
                        "(revision builds; the main_tables job is never numbered)")
    args = p.parse_args(argv)
    if not str(args.out_dir).strip() or str(args.out_dir) == ".":
        p.error("--out-dir must name a directory (an empty value would write into the project root)")
    if "/" in args.suffix or "\\" in args.suffix:
        p.error(f"--suffix must not contain a path separator: {args.suffix!r}")
    return args


def main(argv=None):
    args = parse_args(argv)
    if not Path("_quarto.yml").exists():
        sys.exit(f"{RED}error: run from the project root (where _quarto.yml lives){NC}")

    jobs = [(name, src, strip_ph) for name, src, strip_ph in JOBS
            if args.only is None or name == args.only]

    print("=" * 40)
    print("Submission DOCX Post-Processing")
    print("=" * 40)
    ok = failed = 0
    for name, src, strip_ph in jobs:
        try:
            assemble(src, strip_ph, args.out_dir, args.suffix,
                     line_numbers=args.line_numbers and name == "manuscript")
            ok += 1
        except Abort as e:
            print(f"{RED}    ERROR: {e}{NC}", file=sys.stderr)
            failed += 1
        print()
    print("=" * 40)
    print(f"Total: {len(jobs)} | {GREEN}Success: {ok}{NC} | {RED}Failed: {failed}{NC}")
    if failed:
        print(f"{RED}Source files are unchanged.{NC}")
        return 1
    print(f"{GREEN}All submission DOCX files assembled!{NC}")
    print(f"\nOutput location:\n  - {args.out_dir}/*{args.suffix}.docx")
    return 0


if __name__ == "__main__":
    sys.exit(main())
