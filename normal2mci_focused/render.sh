#!/bin/bash
# render.sh - Render normal-to-MCI focused DMP analysis
#
# Two steps:
#   Step 1: DMP scatter, extended scatter, effect size correlation (independent)
#   Step 2: Patch figures (read Step 1 RDS outputs)
#
# Excluded: 04_gene_dementia_function.qmd
#   — not referenced by ms/fig_tbl.
#
# Rendered elsewhere: 05_zero_pvalue_check.qmd (reviewer round, R1.5/R2.7)
#   — rendered by manage_project/render_manuscript.sh in its REVIEWER CHECKS
#   stage, after Pipeline C. Besides this folder's and validation/'s outputs it
#   reads saved outputs of stable_mci_focused/ (rendered after this script),
#   Pipeline B (UMAP/lite/, VAE/lite/, VAE_UMAP_comb/, APOE/) and Pipeline C
#   (pathway_analysis/), none of which exist yet when this script runs under
#   --all on a fresh clone. To re-run it alone once they exist:
#   quarto render normal2mci_focused/05_zero_pvalue_check.qmd --to html
#
# Usage: bash normal2mci_focused/render.sh

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
echo "Normal-to-MCI Focused Render Script"
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
echo "--- Step 1: DMP scatter, extended scatter, effect size correlation ---"

render_html "normal2mci_focused/01_DMP_scatter.qmd"
render_html "normal2mci_focused/02_Extended_DMP_scatter.qmd"
render_html "normal2mci_focused/03_effect_size_corr.qmd"

echo ""

# ========================================
# Step 2: Patch figures (read Step 1 RDS)
# ========================================
echo "--- Step 2: Patch figures ---"

render_html "normal2mci_focused/patch_figures/01_patch_main_fig.qmd"
render_html "normal2mci_focused/patch_figures/02_patch_suppl_fig.qmd"

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
    echo "  - normal2mci_focused/output/*.rds                  (scatter/correlation data)"
    echo "  - normal2mci_focused/output/*.png                  (individual plots)"
    echo "  - normal2mci_focused/patch_figures/output/*.png    (composite figures)"
fi
