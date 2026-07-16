#!/bin/bash
# render.sh - Render DMP (differentially methylated position) analysis
#
# Two steps with dependency:
#   1. Manhattan plot (produces RDS for patch figure)
#   2. Supplementary patch figure (reads Manhattan RDS)
#
# Note: 02_genomic_inflation.qmd is a standalone sensitivity analysis; run it by hand.
#
# Usage: bash dmp/render.sh

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
echo "DMP Render Script"
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
# Step 1: Manhattan plot
# ========================================
echo "--- Step 1: Manhattan plot ---"

render_html "dmp/01_Manhattan_plot.qmd"

echo ""

# ========================================
# Step 2: Supplementary patch figure
# ========================================
echo "--- Step 2: Supplementary patch figure (reads Manhattan RDS) ---"

render_html "dmp/patch_figures/01_patch_suppl_figure.qmd"

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
    echo "  - dmp/output/*.rds                            (Manhattan plot data)"
    echo "  - dmp/patch_figures/output/fig_suppl_5_manhattan.png  (supplementary figure)"
fi
