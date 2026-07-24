#!/bin/bash
# post_process_pdf.sh - Assemble journal-submission PDFs from the rendered outputs
#
# Takes the PDFs produced by ms/render.sh and, for each one:
#   - strips the auto-generated front matter (title page + table of contents)
#   - strips trailing/placeholder pages that exist only to satisfy the renderer
#   - prepends a clean title page
#   - stamps continuous page numbers: title page blank, content 1, 2, 3, ...
#     (the stale baked-in number stripping leaves behind is masked over)
#
# Handles four documents:
#   ms/fig_tbl/main_figures.pdf          -> "Main Figures"
#   ms/fig_tbl/supplementary_figures.pdf -> "Supplementary Figures"
#   ms/fig_tbl/tables.pdf                -> "Tables and Supplementary Tables"
#   ms/write-ms/dementia_EWAS.pdf        -> the manuscript title
#
# The first three are then concatenated into figures_and_tables.pdf, and are
# also kept as separate files. The combined file is NOT renumbered: it is built
# from the already-renumbered parts, so each section shows a blank divider then
# content 1..N (per-section numbering).
#
# Outputs go to ms/submission/. Source PDFs are never modified.
#
# Pages to drop are DETECTED, not hardcoded, so that re-rendering the manuscript
# (which shifts pagination whenever prose or the float list changes) cannot
# silently leave a placeholder page in a submission file.
#
# Usage: bash ms/post_process_pdf.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

OUT_DIR="ms/submission"

# Counters
TOTAL=0
SUCCESS=0
FAILED=0

# Outputs produced by THIS run. The merge step consults it so that a stale file
# left in ms/submission/ by an earlier run can never be folded into the combined
# PDF after its own assembly step has failed.
ASSEMBLED=()

TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ========================================
# Helpers
# ========================================

# Reports a problem and returns success. It must NOT return non-zero: under
# `set -e` the command following the final `||` is still subject to errexit, so
# a failing `die` inside `... || { die ...; return 0; }` aborts the whole script
# before the counter is read -- which made the summary below unreachable and
# stopped one bad input from letting the remaining files build.
die() {
    echo -e "${RED}    ERROR: $*${NC}" >&2
}

# Records an anticipated failure and reports it. Callers return straight after.
fail() {
    die "$@"
    FAILED=$((FAILED + 1))
}

page_count() {
    pdfinfo "$1" | awk '/^Pages:/ {print $2}'
}

# Every grep here goes through `command grep`. An interactive shell may define
# grep as a function or alias pointing at a different implementation, and the
# exit status of `grep -qv` is not portable across them -- which silently
# inverts the page tests below.
PLACEHOLDER_RE='^(Figure|Table) [0-9]+$|^Supplementary (Fig\.|Table|Data) [0-9]+$'

# Text of one page, with Typst's margin line numbers and the page number removed.
page_text() {
    pdftotext -f "$2" -l "$2" "$1" - 2>/dev/null |
        command grep -v '^[[:space:]]*$' |
        command grep -vE '^[0-9]+$' || true
}

# A table-of-contents page is dense with dot leaders ("Results . . . . . 6").
# The manuscript's title page carries the start of the TOC, so it matches too.
is_toc_page() {
    local n
    n=$(pdftotext -f "$2" -l "$2" "$1" - 2>/dev/null | command grep -c '\. \. \.' || true)
    [[ "${n:-0}" -ge 3 ]]
}

# A placeholder page holds nothing but bare float labels, emitted by
# ms/fig_tbl/_pseudo_figures.qmd so that cross-references resolve. Counting the
# lines that fail to match is used in preference to `grep -qv`.
#
# Two conditions, not one. A real table page carries the table as an image and
# so contributes only its own heading to the text layer -- indistinguishable
# from a placeholder on the first test alone (tables.pdf pages 9-12 are exactly
# this). Placeholder pages stack many labels together: 7-14 each here, against
# exactly 1 on a real page.
is_placeholder_page() {
    local text n_other n_labels
    text=$(page_text "$1" "$2")
    [[ -n "$text" ]] || return 1
    n_other=$(printf '%s\n' "$text" | command grep -cvE "$PLACEHOLDER_RE" || true)
    [[ "${n_other:-1}" -eq 0 ]] || return 1
    n_labels=$(printf '%s\n' "$text" | command grep -cE "$PLACEHOLDER_RE" || true)
    [[ "${n_labels:-0}" -ge 2 ]]
}

# Build a one-page title PDF using the Typst binary bundled with Quarto -- the
# same engine that produced the body, so fonts and metrics match.
make_title_page() {
    local text="$1" out="$2" size="${3:-20pt}" typ
    typ="$TMP_DIR/title_$$.typ"

    # Escape for a Typst string literal so markup characters stay literal.
    local escaped=${text//\\/\\\\}
    escaped=${escaped//\"/\\\"}

    cat >"$typ" <<EOF
#set page(paper: "us-letter", margin: 1in)
#set par(justify: false, leading: 0.8em)
#set align(center + horizon)
#let title = "$escaped"
#block(width: 85%)[#text(size: $size, weight: "bold")[#title]]
EOF

    quarto typst compile "$typ" "$out" >/dev/null || return 1
    [[ -s "$out" ]]
}

# qpdf exits 3 when it succeeded but emitted warnings, and 2 on a real error.
# Under `set -e` an unhandled 3 would abort a run that actually worked.
run_qpdf() {
    local rc=0
    qpdf "$@" || rc=$?
    if [[ $rc -eq 3 ]]; then
        echo -e "${YELLOW}    (qpdf reported warnings)${NC}"
        return 0
    fi
    return "$rc"
}

# Collapse a sorted list of page numbers into qpdf range syntax (3-22,27-31).
to_ranges() {
    local pages=("$@") out="" start prev p
    [[ ${#pages[@]} -gt 0 ]] || return 1
    start=${pages[0]}
    prev=${pages[0]}
    for p in "${pages[@]:1}"; do
        if [[ $p -ne $((prev + 1)) ]]; then
            out+="${out:+,}$start$([[ $start -ne $prev ]] && echo "-$prev")"
            start=$p
        fi
        prev=$p
    done
    out+="${out:+,}$start$([[ $start -ne $prev ]] && echo "-$prev")"
    printf '%s' "$out"
}

# ========================================
# Assembly
# ========================================
#
# mode "float"  -- figure/table documents: drop page 1 and the trailing
#                  Bibliography page.
# mode "manuscript" -- drop the leading TOC pages and every placeholder page,
#                  keeping the real bibliography.

assemble() {
    local src="$1" title="$2" mode="$3" size="${4:-20pt}"
    local base out n keep=() dropped_front=() dropped_other=() p

    TOTAL=$((TOTAL + 1))
    base=$(basename "$src")
    out="$OUT_DIR/$base"
    echo -e "${YELLOW}[$TOTAL] Assembling:${NC} $base"

    [[ -f "$src" ]] || { fail "missing input: $src (run ms/render.sh first)"; return 0; }

    n=$(page_count "$src")
    [[ "$n" -gt 2 ]] || { fail "$base has only $n pages"; return 0; }

    if [[ "$mode" == "float" ]]; then
        # Guard the two assumptions rather than trusting page positions.
        pdftotext -f 1 -l 1 "$src" - 2>/dev/null | command grep -q 'Contents' ||
            { fail "page 1 of $base is not the contents page"; return 0; }
        page_text "$src" "$n" | command grep -q '^Bibliography$' ||
            { fail "last page of $base is not the empty bibliography"; return 0; }

        dropped_front=(1)
        dropped_other=("$n")
        for ((p = 2; p < n; p++)); do keep+=("$p"); done
    else
        # Leading run of title/TOC pages.
        for ((p = 1; p <= n; p++)); do
            if is_toc_page "$src" "$p"; then dropped_front+=("$p"); else break; fi
        done
        [[ ${#dropped_front[@]} -gt 0 ]] ||
            { fail "no front matter found in $base"; return 0; }

        # Placeholder pages, anywhere in the body.
        for ((p = ${#dropped_front[@]} + 1; p <= n; p++)); do
            if is_placeholder_page "$src" "$p"; then
                dropped_other+=("$p")
            else
                keep+=("$p")
            fi
        done
        [[ ${#dropped_other[@]} -gt 0 ]] ||
            { fail "no cross-reference placeholder pages found in $base"; return 0; }
    fi

    [[ ${#keep[@]} -gt 0 ]] || { fail "nothing left to keep in $base"; return 0; }

    local ranges
    ranges=$(to_ranges "${keep[@]}")

    make_title_page "$title" "$TMP_DIR/title.pdf" "$size" ||
        { fail "could not build the title page for $base"; return 0; }
    run_qpdf "$src" --pages . "$ranges" -- "$TMP_DIR/body.pdf" ||
        { fail "qpdf could not extract $ranges from $base"; return 0; }
    run_qpdf --empty --pages "$TMP_DIR/title.pdf" "$TMP_DIR/body.pdf" -- "$out" ||
        { fail "qpdf could not write $out"; return 0; }

    renumber "$out" ||
        { fail "could not renumber $base"; return 0; }

    echo "    title page: \"$title\""
    echo "    dropped front matter: ${dropped_front[*]}"
    echo "    dropped other:        ${dropped_other[*]:-none}"
    echo "    kept $ranges  ->  $(page_count "$out") pages"
    echo "    renumbered: page 1 blank, content 1..$(( $(page_count "$out") - 1 ))"
    echo -e "${GREEN}    Done${NC} $out"
    ASSEMBLED+=("$out")
    SUCCESS=$((SUCCESS + 1))
}

# Concatenate finished submission PDFs into one file, leaving the parts in
# place. No extra title page is added: each part already opens with its own,
# which then reads as a section divider in the combined document.
was_assembled() {
    local target="$1" f
    for f in ${ASSEMBLED[@]+"${ASSEMBLED[@]}"}; do
        [[ "$f" == "$target" ]] && return 0
    done
    return 1
}

merge() {
    local out="$OUT_DIR/$1"; shift
    local parts=("$@") part total=0 n

    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}[$TOTAL] Merging:${NC} $(basename "$out")"

    for part in "${parts[@]}"; do
        was_assembled "$part" ||
            { fail "$(basename "$part") was not assembled in this run; refusing to merge"; return 0; }
    done

    run_qpdf --empty --pages "${parts[@]}" -- "$out" ||
        { fail "qpdf could not write $out"; return 0; }

    for part in "${parts[@]}"; do
        n=$(page_count "$part")
        total=$((total + n))
        echo "    + $(basename "$part") ($n pages)"
    done

    n=$(page_count "$out")
    [[ "$n" -eq "$total" ]] ||
        { fail "merged page count $n does not equal the sum of the parts ($total)"; return 0; }

    echo "    $total pages total"
    echo -e "${GREEN}    Done${NC} $out"
    SUCCESS=$((SUCCESS + 1))
}

# Stamp continuous page numbers onto an assembled PDF: page 1 (the prepended
# title/divider page) is left blank; every later page is numbered 1, 2, 3, ...
#
# The old baked-in footer number is hidden under an opaque white mask -- it is
# NOT removed. qpdf --overlay draws the overlay on top of the base page, so the
# original number survives in the text layer (extractable, invisible) beneath a
# white rectangle. This is inherent to the toolchain (no installed tool can
# delete base content); visually the page shows only the new number.
#
# The overlay is a Typst document with `fill: none` (transparent page) so the
# base shows through everywhere except the mask, composited with qpdf --overlay
# -- the same engine used throughout this script. Geometry (dy/size) matches the
# Quarto/Typst default footer number measured on the rendered PDF; verified by
# eye, not grep.
renumber() {
    local target="$1" base typ over tmp T ov
    base=$(basename "$target")
    T=$(page_count "$target")

    # Only the title page -- nothing to number.
    [[ "${T:-0}" -ge 2 ]] || return 0

    typ="$TMP_DIR/overlay_${base}.typ"
    over="$TMP_DIR/overlay_${base}.pdf"
    tmp="$TMP_DIR/renum_${base}"

    # One letter page per target page. Page 1 emits nothing (stays transparent);
    # pages 2..T carry the footer mask plus the fresh number k-1. margin:0pt so
    # `place` is page-absolute; no `$`/backtick in the body, so the unquoted
    # heredoc leaves the Typst verbatim (only $T is expanded).
    cat >"$typ" <<EOF
#set page(paper: "us-letter", margin: 0pt, fill: none)
#let total = $T
#for k in range(1, total + 1) {
  if k > 1 { pagebreak(weak: false) }
  if k >= 2 {
    place(bottom + center, dy: -44pt,
      rect(width: 100%, height: 30pt, fill: white, stroke: none))
    place(bottom + center, dy: -56pt, text(size: 11pt)[#(k - 1)])
  }
}
EOF

    quarto typst compile "$typ" "$over" >/dev/null 2>&1 || return 1
    ov=$(page_count "$over")
    [[ "${ov:-0}" -eq "$T" ]] || return 1          # overlay must align 1:1
    run_qpdf "$target" --overlay "$over" -- "$tmp" || return 1
    [[ "$(page_count "$tmp")" -eq "$T" ]] || return 1
    run_qpdf --check "$tmp" >/dev/null 2>&1 || return 1
    mv "$tmp" "$target"
}

# ========================================
# Main
# ========================================

echo "========================================"
echo "Submission PDF Post-Processing"
echo "========================================"
echo ""

# Verify we're in the project root
if [[ ! -f "_quarto.yml" ]]; then
    echo -e "${RED}Error: Must run from project root (where _quarto.yml is located)${NC}"
    exit 1
fi

for tool in qpdf pdfinfo pdftotext quarto; do
    command -v "$tool" >/dev/null 2>&1 ||
        { echo -e "${RED}Error: required tool not found: $tool${NC}"; exit 1; }
done

TMP_DIR=$(mktemp -d)
mkdir -p "$OUT_DIR"

echo "Starting post-processing..."
echo ""

echo "--- Figures and tables ---"
assemble "ms/fig_tbl/main_figures.pdf"          "Main Figures"                    float
assemble "ms/fig_tbl/supplementary_figures.pdf" "Supplementary Figures"           float
assemble "ms/fig_tbl/tables.pdf"                "Tables and Supplementary Tables" float

echo ""
echo "--- Combined figures and tables ---"
merge "figures_and_tables.pdf" \
    "$OUT_DIR/main_figures.pdf" \
    "$OUT_DIR/supplementary_figures.pdf" \
    "$OUT_DIR/tables.pdf"

echo ""
echo "--- Manuscript text ---"
assemble "ms/write-ms/dementia_EWAS.pdf" \
    "Blood DNA methylation traces an epigenetic trajectory across stages of dementia progression" \
    manuscript 18pt

echo ""
echo "========================================"
echo "Post-Processing Complete"
echo "========================================"
echo -e "Total: $TOTAL | ${GREEN}Success: $SUCCESS${NC} | ${RED}Failed: $FAILED${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Some files failed. Source PDFs are unchanged; check output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All submission PDFs assembled!${NC}"
    echo ""
    echo "Output location:"
    echo "  - $OUT_DIR/*.pdf"
fi
