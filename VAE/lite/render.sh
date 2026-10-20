#!/bin/bash
# render.sh - Render the VAE lite pipeline in dependency order
#
# Simplified VAE analysis: single configuration (beta=0.001),
# average ensemble, Path2D DPS only, thresholds 7 & 8.
#
# Execution order:
#   1. VAE embedding (training + average ensemble)
#   1b. Cross-validation fold composition (reviewer-round check; no float)
#   2. Density peak analysis (centroids, correlations)
#   3. Path2D DPS computation and ranking
#   4. DPS visualization, scatter contour, boxplots (parallel-safe)
#   5. Permutation test (1000 label permutations)
#   6. Permutation visualization (null distribution + p-values)
#
# Usage: bash VAE/lite/render.sh

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

render_html_params() {
    local file="$1"
    shift
    TOTAL=$((TOTAL + 1))
    echo -e "${YELLOW}[$TOTAL] Rendering:${NC} $file $*"
    if quarto render "$file" --to html "$@"; then
        SUCCESS=$((SUCCESS + 1))
        echo -e "${GREEN}    Done${NC}"
    else
        FAILED=$((FAILED + 1))
        echo -e "${RED}    FAILED${NC}"
        return 1
    fi
}

echo "========================================"
echo "VAE Lite Pipeline Render Script"
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
# Step 1: VAE embedding
# ========================================
echo "--- Step 1: VAE embedding (beta=0.001, 5-fold CV, average ensemble, thresholds 7 & 8) ---"

render_html "VAE/lite/01_vae_embedding.qmd"

echo ""

# ========================================
# Step 1b: Cross-validation fold composition
# ========================================
# ADJ-D-26-02882 reviewer round (R2.5). Rebuilds the 5-fold split of Step 1
# without training and tabulates the held-out groups; read only by the response
# letter, no manuscript float. Reads the Step 1 embeddings for an identity check.
echo "--- Step 1b: Cross-validation fold composition (reviewer-round check; no float) ---"

render_html "VAE/lite/02_cv_fold_composition.qmd"

echo ""

# ========================================
# Step 2: Density peak analysis
# ========================================
echo "--- Step 2: Density peak analysis (centroids, correlations, plot limits) ---"

render_html "VAE/lite/DPS/01_density_peak_analysis.qmd"

echo ""

# ========================================
# Step 3: Path2D DPS computation
# ========================================
echo "--- Step 3: Path2D DPS computation and ranking ---"

render_html "VAE/lite/DPS/02_dps_path2d.qmd"

echo ""

# ========================================
# Step 4: Visualizations (independent of each other)
# ========================================
echo "--- Step 4: DPS visualization, scatter contour, boxplots ---"

render_html "VAE/lite/DPS/03_dps_visualization.qmd"
render_html "VAE/lite/scatter/01_scatter_contour.qmd"
render_html_params "VAE/lite/latent_coordinates/01_boxplot.qmd" -P threshold:8
mv VAE/lite/latent_coordinates/01_boxplot.html VAE/lite/latent_coordinates/01_boxplot_threshold_8.html

render_html_params "VAE/lite/latent_coordinates/01_boxplot.qmd" -P threshold:7
mv VAE/lite/latent_coordinates/01_boxplot.html VAE/lite/latent_coordinates/01_boxplot_threshold_7.html

echo ""

# ========================================
# Step 5: Permutation test
# ========================================
echo "--- Step 5: Permutation test (1000 permutations, both thresholds) ---"

render_html "VAE/lite/permutation/01_permutation_dps.qmd"

echo ""

# ========================================
# Step 6: Permutation visualization
# ========================================
echo "--- Step 6: Permutation visualization (null distribution + p-values) ---"

render_html "VAE/lite/permutation/02_permutation_visualization.qmd"

echo ""

# ========================================
# Step 7: VAE methodology figures (independent)
# ========================================
echo "--- Step 7: VAE methodology figures (architecture + CV visualization) ---"

render_html "VAE/lite/VAE_graph/01_vae_architecture_viz.qmd"
render_html "VAE/lite/VAE_graph/02_vae_cv_viz.qmd"

echo ""

# ========================================
# Step 8: VAE methodology patch figure
# ========================================
echo "--- Step 8: VAE methodology patch figure ---"

render_html "VAE/lite/VAE_graph/03_patch_vae_figures.qmd"

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
    echo "  - VAE/lite/output/*.rds                                  (embeddings)"
    echo "  - VAE/lite/output/cv_fold_composition.rds                (fold composition)"
    echo "  - VAE/lite/DPS/output/*.rds                              (centroids, DPS results)"
    echo "  - VAE/lite/DPS/output/fig_tbl/*.png                      (DPS plots)"
    echo "  - VAE/lite/scatter/output/fig_tbl/threshold{7,8}/*.png   (scatter plots)"
    echo "  - VAE/lite/latent_coordinates/output/fig_tbl/*.png       (boxplots)"
    echo "  - VAE/lite/permutation/output/*.rds                      (permutation data)"
    echo "  - VAE/lite/permutation/output/fig_tbl/threshold_{7,8}/*.png (permutation plots)"
    echo "  - VAE/lite/VAE_graph/output/*.png                      (methodology figures)"
fi
