#!/bin/bash
# render.sh - Render APOE analysis
#
# Cross-directory dependency: requires UMAP/lite and VAE/lite embeddings.
# Run UMAP/lite/render.sh and VAE/lite/render.sh first.
#
# Two steps:
#   Step 1: APOE dementia table + combined boxplots (independent)
#   Step 2: Patch figures (read Step 1 outputs)
#
#
# Usage: bash APOE/render.sh

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
echo "APOE Render Script"
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
# Step 1: Table and combined boxplots (independent)
# ========================================
echo "--- Step 1: APOE dementia table and combined boxplots ---"

render_html "APOE/01_APOE_dementia_table.qmd"
render_html "APOE/06_APOE_boxplots_combined.qmd"

echo ""

# ========================================
# Step 2: Patch figures
# ========================================
echo "--- Step 2: Patch figures ---"

render_html "APOE/patch_figures/01_patch_main_apoe_boxplot.qmd"
render_html "APOE/patch_figures/02_patch_suppl_apoe_boxplot.qmd"

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
    echo "  - APOE/output/*.png                        (table and boxplot images)"
    echo "  - APOE/patch_figures/output/*.png           (composite figures)"
fi
