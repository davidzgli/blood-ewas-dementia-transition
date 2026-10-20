#!/bin/bash
# render.sh - Render validation analysis pipeline in dependency order
#
# Four dependency levels:
#   Level 0: Reference comparison table (no dependencies)
#   Level 1: Individual validation comparisons (read shared data)
#   Level 2: Directionality analyses + correlation trend (read Level 1 outputs)
#   Level 3: Combined directionality + supplementary patch figure
#   Level 4: Main validation patch figure (reads all prior outputs)
#   Level 5: Reviewer-response check (reads Level 1-2 outputs; no float)
#
# Usage: bash validation/render.sh

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
echo "Validation Pipeline Render Script"
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
# Level 0: Base files (no dependencies)
# ========================================
echo "--- Level 0: Reference comparison table ---"

render_html "validation/06_reference_comparison_table.qmd"

echo ""

# ========================================
# Level 1: Validation comparisons
# ========================================
echo "--- Level 1: Validation comparison analyses ---"

render_html "validation/01_ADNI_AIBL_comparison.qmd"
render_html "validation/02_CSF_pTau_CN_comparison.qmd"
render_html "validation/03_CSF_total_Tau_CN_comparison.qmd"
render_html "validation/05_AddNeuroMed_comparison.qmd"

echo ""

# ========================================
# Level 2: Directionality and correlation
# ========================================
echo "--- Level 2: Directionality and correlation analyses ---"

render_html "validation/10a_directionality_ADNI_AIBL.qmd"
render_html "validation/10b_directionality_CSF_pTau_CN.qmd"
render_html "validation/10c_directionality_CSF_total_Tau_CN.qmd"
render_html "validation/10d_directionality_AddNeuroMed.qmd"
render_html "validation/04d_correlation_trend_combined.qmd"

echo ""

# ========================================
# Level 3: Combined analyses
# ========================================
echo "--- Level 3: Combined directionality and supplementary patch figure ---"

render_html "validation/10e_directionality_combined.qmd"
render_html "validation/patch_figures/02_patch_suppl_figure.qmd"

echo ""

# ========================================
# Level 4: Main figure composition
# ========================================
echo "--- Level 4: Main validation patch figure ---"

render_html "validation/patch_figures/01_patch_main_figure.qmd"

echo ""

# ========================================
# Level 5: Reviewer-response check
# ========================================
# ADJ-D-26-02882 reviewer round (R2.8). Response letter only; no manuscript
# float reads its outputs. Reads Level 1-2 outputs (and data/), overwrites none,
# and writes directionality_results_AddNeuroMed_single_trim.rds and
# dmp_overlap_ADNI_AIBL_AddNeuroMed.rds.
echo "--- Level 5: Reviewer-response check (no manuscript float) ---"

# R2.8: single- vs double-trimmed AddNeuroMed sign tests; 403-DMP overlap
render_html "validation/11_directionality_trim_check.qmd"

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
    echo "  - validation/output/*.rds                        (comparison data)"
    echo "  - validation/output/*.png                        (individual plots)"
    echo "  - validation/patch_figures/output/*.png           (composite figures)"
fi
