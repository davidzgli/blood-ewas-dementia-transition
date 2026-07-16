#!/bin/bash
# render.sh - Render extended data tables for supplementary Excel files
#
# Cross-directory dependency: 03_biofunc_to_excel.qmd requires
# pathway_analysis outputs. Run pathway_analysis/render.sh first.
#
# Three steps:
#   Step 1: DMP403 CpG Excel + CpG-to-Excel (independent)
#   Step 2: Biofunc-to-Excel (reads pathway_analysis outputs)
#   Step 3: Combine Excel (reads outputs from Steps 1-2)
#
# Usage: bash extended_data/render.sh

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

render_html() {
    local file="$1"
    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}[$TOTAL] Rendering:${NC} $file"
    if quarto render "$file" --to html; then
        SUCCESS=$((SUCCESS + 1))
        echo -e "${GREEN}    Done${NC}"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}    FAILED${NC}"
        return 1
    fi
}

echo "========================================"
echo "Extended Data Render Script"
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
# Step 1: DMP403 CpG Excel and CpG-to-Excel (independent)
# ========================================
echo "--- Step 1: DMP403 CpG Excel and CpG-to-Excel ---"

render_html "extended_data/01_DMP403_cg_excel.qmd"
render_html "extended_data/02_cg_to_excel.qmd"

echo ""

# ========================================
# Step 2: Biofunc-to-Excel (reads pathway_analysis outputs)
# ========================================
echo "--- Step 2: Biofunc-to-Excel (reads pathway_analysis outputs) ---"

render_html "extended_data/03_biofunc_to_excel.qmd"

echo ""

# ========================================
# Step 3: Combine Excel (reads Steps 1-2 outputs)
# ========================================
echo "--- Step 3: Combine all Excel sheets ---"

render_html "extended_data/04_combine_excel.qmd"

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
    echo "  - extended_data/output/*.xlsx  (individual Excel sheets)"
    echo "  - extended_data/output/*.xlsx  (combined Excel workbook)"
fi
