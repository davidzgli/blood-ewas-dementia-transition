#!/bin/bash
# render.sh - Render stable-MCI focused DMP analysis
#
# Two steps:
#   Step 1: DMP scatter, extended DMP scatter (independent)
#   Step 2: Patch figures (read Step 1 RDS outputs)
#
# Both figures are supplementary-only; there is no main-figure patch step.
#
# Usage: bash stable_mci_focused/render.sh

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
echo "Stable-MCI Focused Render Script"
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
# Step 1: Individual analyses (independent)
# ========================================
echo "--- Step 1: DMP scatter, extended DMP scatter ---"

render_html "stable_mci_focused/01_DMP_scatter.qmd"
render_html "stable_mci_focused/02_Extended_DMP_scatter.qmd"

echo ""

# ========================================
# Step 2: Patch figures (read Step 1 RDS)
# ========================================
echo "--- Step 2: Patch figures ---"

render_html "stable_mci_focused/patch_figures/01_patch_suppl_fig.qmd"

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
    echo "  - stable_mci_focused/output/*.rds                  (scatter plot objects)"
    echo "  - stable_mci_focused/patch_figures/output/*.png    (supplementary figures)"
fi
