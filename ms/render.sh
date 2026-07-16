#!/bin/bash
# render.sh - Render manuscript final products (PDF via Typst + DOCX)
#
# Renders each manuscript file to both PDF (Typst) and DOCX formats:
#   - Main figures
#   - Supplementary figures
#   - Tables
#   - Manuscript text
#
# Requires all analysis pipelines to be complete first.
#
# Usage: bash ms/render.sh

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
SUCCESS=0
FAILED=0

render_pdf() {
    local file="$1"
    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}[$TOTAL] Rendering (PDF):${NC} $file"
    if quarto render "$file" --to typst; then
        SUCCESS=$((SUCCESS + 1))
        echo -e "${GREEN}    Done${NC}"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}    FAILED${NC}"
        return 1
    fi
}

render_docx() {
    local file="$1"
    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}[$TOTAL] Rendering (DOCX):${NC} $file"
    if quarto render "$file" --to docx; then
        SUCCESS=$((SUCCESS + 1))
        echo -e "${GREEN}    Done${NC}"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}    FAILED${NC}"
        return 1
    fi
}

echo "========================================"
echo "Manuscript Render Script"
echo "========================================"
echo ""

# Verify we're in the project root
if [[ ! -f "_quarto.yml" ]]; then
    echo -e "${RED}Error: Must run from project root (where _quarto.yml is located)${NC}"
    exit 1
fi

echo "Starting render pipeline..."
echo ""

# ========================================
# Figures and tables
# ========================================
echo "--- Main figures ---"
render_pdf "ms/fig_tbl/main_figures.qmd"
render_docx "ms/fig_tbl/main_figures.qmd"

echo ""
echo "--- Supplementary figures ---"
render_pdf "ms/fig_tbl/supplementary_figures.qmd"
render_docx "ms/fig_tbl/supplementary_figures.qmd"

echo ""
echo "--- Tables ---"
render_pdf "ms/fig_tbl/tables.qmd"
render_docx "ms/fig_tbl/tables.qmd"

echo ""

# ========================================
# Manuscript text
# ========================================
echo "--- Manuscript text ---"
render_pdf "ms/write-ms/dementia_EWAS.qmd"
render_docx "ms/write-ms/dementia_EWAS.qmd"

echo ""
echo "========================================"
echo "Render Complete"
echo "========================================"
echo -e "Total: $TOTAL | ${GREEN}Success: $SUCCESS${NC} | ${RED}Failed: $FAILED${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Some files failed to render. Check output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All files rendered successfully!${NC}"
    echo ""
    echo "Output locations:"
    echo "  - ms/fig_tbl/*.pdf           (figure/table PDFs)"
    echo "  - ms/fig_tbl/*.docx          (figure/table DOCX)"
    echo "  - ms/write-ms/*.pdf          (manuscript PDF)"
    echo "  - ms/write-ms/*.docx         (manuscript DOCX)"
fi
