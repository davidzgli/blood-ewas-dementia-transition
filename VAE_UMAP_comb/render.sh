#!/bin/bash
# render.sh - Render VAE-UMAP combined analysis
#
# Cross-directory dependency: requires UMAP/lite and VAE/lite full pipeline
# outputs (embeddings, DPS, scatter, boxplots, permutation).
# Run UMAP/lite/render.sh and VAE/lite/render.sh first.
#
# Two steps:
#   Step 1: Dimension ANOVA, DPS visualization, permutation visualization
#   Step 2: Patch figures (read Step 1 outputs + UMAP/VAE individual outputs)
#
# Usage: bash VAE_UMAP_comb/render.sh

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
echo "VAE-UMAP Combined Render Script"
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
# Step 1: Cross-method analyses
# ========================================
echo "--- Step 1: Dimension ANOVA, DPS visualization, permutation visualization ---"

render_html "VAE_UMAP_comb/01_dimension_anova.qmd"
render_html "VAE_UMAP_comb/02_dps_visualization.qmd"
render_html "VAE_UMAP_comb/03_permutation_visualization.qmd"

echo ""

# ========================================
# Step 2: Patch composite PNGs
# ========================================
echo "--- Step 2: Patch composite PNGs ---"

render_html "VAE_UMAP_comb/patch_figures/01a_patch_main_boxplots.qmd"
render_html "VAE_UMAP_comb/patch_figures/01b_patch_main_scatter_peak.qmd"
render_html "VAE_UMAP_comb/patch_figures/02a_patch_suppl_boxplots.qmd"
render_html "VAE_UMAP_comb/patch_figures/02b_patch_suppl_scatter_peak.qmd"
render_html "VAE_UMAP_comb/patch_figures/02c_patch_suppl_permutation.qmd"

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
    echo "  - VAE_UMAP_comb/output/*.rds                       (analysis data)"
    echo "  - VAE_UMAP_comb/output/*.png                       (individual plots)"
    echo "  - VAE_UMAP_comb/patch_figures/output/*.png          (composite figures)"
fi
