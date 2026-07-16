#!/bin/bash
# render.sh - Render the UMAP lite pipeline in dependency order
#
# Simplified UMAP analysis: single configuration (nn=10, md=0.5),
# seed-averaged embeddings, Path2D DPS only, thresholds 7 & 8.
#
# Execution order:
#   1. Embedding (UMAP computation + seed averaging)
#   2. Density peak analysis (centroids, correlations)
#   3. Path2D DPS computation and ranking
#   4. DPS visualization, scatter contour, boxplots (parallel-safe)
#   5. Permutation test (1000 label permutations)
#   6. Permutation visualization (null distribution + p-values)
#
# Usage: bash UMAP/lite/render.sh

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
echo "UMAP Lite Pipeline Render Script"
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
# Step 1: UMAP embedding
# ========================================
echo "--- Step 1: UMAP embedding (nn=10, md=0.5, 5 seeds, thresholds 7 & 8) ---"

render_html "UMAP/lite/01_umap_embedding.qmd"

echo ""

# ========================================
# Step 2: Density peak analysis
# ========================================
echo "--- Step 2: Density peak analysis (centroids, correlations, plot limits) ---"

render_html "UMAP/lite/DPS/01_density_peak_analysis.qmd"

echo ""

# ========================================
# Step 3: Path2D DPS computation
# ========================================
echo "--- Step 3: Path2D DPS computation and ranking ---"

render_html "UMAP/lite/DPS/02_dps_path2d.qmd"

echo ""

# ========================================
# Step 4: Visualizations (independent of each other)
# ========================================
echo "--- Step 4: DPS visualization, scatter contour, boxplots ---"

render_html "UMAP/lite/DPS/03_dps_visualization.qmd"
render_html "UMAP/lite/scatter/01_scatter_contour.qmd"
render_html_params "UMAP/lite/latent_coordinates/01_boxplot.qmd" -P threshold:8
mv UMAP/lite/latent_coordinates/01_boxplot.html UMAP/lite/latent_coordinates/01_boxplot_threshold_8.html

render_html_params "UMAP/lite/latent_coordinates/01_boxplot.qmd" -P threshold:7
mv UMAP/lite/latent_coordinates/01_boxplot.html UMAP/lite/latent_coordinates/01_boxplot_threshold_7.html

echo ""

# ========================================
# Step 5: Permutation test
# ========================================
echo "--- Step 5: Permutation test (1000 permutations, both thresholds) ---"

render_html "UMAP/lite/permutation/01_permutation_dps.qmd"

echo ""

# ========================================
# Step 6: Permutation visualization
# ========================================
echo "--- Step 6: Permutation visualization (null distribution + p-values) ---"

render_html "UMAP/lite/permutation/02_permutation_visualization.qmd"

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
    echo "  - UMAP/lite/output/*.rds"
    echo "  - UMAP/lite/DPS/output/fig_tbl/*.png"
    echo "  - UMAP/lite/scatter/output/fig_tbl/threshold{7,8}/*.png"
    echo "  - UMAP/lite/latent_coordinates/output/fig_tbl/*.png"
    echo "  - UMAP/lite/permutation/output/fig_tbl/threshold_{7,8}/*.png"
fi
