#!/bin/bash
# render.sh - Render the pathway analysis pipeline in dependency order
#
# Full pathway analysis: gene comparison, GO enrichment,
# transition-specific GO terms, function categorization,
# and figure/table generation.
#
# Parameterized files are rendered twice (top_n 1000 and 2000)
# with HTML outputs renamed to avoid overwrites.
#
# Execution order:
#   1. Gene comparison (top_n 1000, 2000)
#   2. P-value with top genes (top_n 2000 hardcoded)
#   3. GO enrichment (top_n 1000, 2000)
#   4. Transition-specific GO terms (top_n 1000, 2000)
#   5. Assign function category (top_n 1000, 2000)
#   6. Analyze function category (top_n 1000, 2000)
#   7. Dementia progress graph
#   8. Patch figures for pathway analysis (main + supplementary)
#
# Usage: bash pathway_analysis/render.sh

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
echo "Pathway Analysis Pipeline Render Script"
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
# Step 1: Gene comparison (top_n 1000, 2000)
# ========================================
echo "--- Step 1: Gene comparison (top_n 1000 & 2000) ---"

render_html_params "pathway_analysis/01_genes/01_compare_genes.qmd" -P top_n:1000
mv pathway_analysis/01_genes/01_compare_genes.html \
   pathway_analysis/01_genes/01_compare_genes_top1000.html

render_html_params "pathway_analysis/01_genes/01_compare_genes.qmd" -P top_n:2000
mv pathway_analysis/01_genes/01_compare_genes.html \
   pathway_analysis/01_genes/01_compare_genes_top2000.html

echo ""

# ========================================
# Step 2: P-value with top genes
# ========================================
echo "--- Step 2: P-value with top genes (top_n 2000, hardcoded) ---"

render_html "pathway_analysis/01_genes/02_pval_with_top_genes.qmd"

echo ""

# ========================================
# Step 3: GO enrichment (top_n 1000, 2000)
# ========================================
echo "--- Step 3: GO enrichment (top_n 1000 & 2000) ---"

render_html_params "pathway_analysis/02_gene_ontology/02_run_GO_enrichment.qmd" -P top_n:1000
mv pathway_analysis/02_gene_ontology/02_run_GO_enrichment.html \
   pathway_analysis/02_gene_ontology/02_run_GO_enrichment_top1000.html

render_html_params "pathway_analysis/02_gene_ontology/02_run_GO_enrichment.qmd" -P top_n:2000
mv pathway_analysis/02_gene_ontology/02_run_GO_enrichment.html \
   pathway_analysis/02_gene_ontology/02_run_GO_enrichment_top2000.html

echo ""

# ========================================
# Step 4: Transition-specific GO terms (top_n 1000, 2000)
# ========================================
echo "--- Step 4: Transition-specific GO terms (top_n 1000 & 2000) ---"

render_html_params "pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms.qmd" -P top_n:1000
mv pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms.html \
   pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms_top1000.html

render_html_params "pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms.qmd" -P top_n:2000
mv pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms.html \
   pathway_analysis/03_transition_specific_GO_terms/generate_transition_specific_GO_terms_top2000.html

echo ""

# ========================================
# Step 5: Assign function category (top_n 1000, 2000)
# ========================================
echo "--- Step 5: Assign function category (top_n 1000 & 2000) ---"

render_html_params "pathway_analysis/04_function_categorization/01_assign_function_category.qmd" -P top_n:1000
mv pathway_analysis/04_function_categorization/01_assign_function_category.html \
   pathway_analysis/04_function_categorization/01_assign_function_category_top1000.html

render_html_params "pathway_analysis/04_function_categorization/01_assign_function_category.qmd" -P top_n:2000
mv pathway_analysis/04_function_categorization/01_assign_function_category.html \
   pathway_analysis/04_function_categorization/01_assign_function_category_top2000.html

echo ""

# ========================================
# Step 6: Analyze function category (top_n 1000, 2000)
# ========================================
echo "--- Step 6: Analyze function category (top_n 1000 & 2000) ---"

render_html_params "pathway_analysis/04_function_categorization/02_analyze_function_category.qmd" -P top_n:1000
mv pathway_analysis/04_function_categorization/02_analyze_function_category.html \
   pathway_analysis/04_function_categorization/02_analyze_function_category_top1000.html

render_html_params "pathway_analysis/04_function_categorization/02_analyze_function_category.qmd" -P top_n:2000
mv pathway_analysis/04_function_categorization/02_analyze_function_category.html \
   pathway_analysis/04_function_categorization/02_analyze_function_category_top2000.html

echo ""

# ========================================
# Step 7: Dementia progress graph
# ========================================
echo "--- Step 7: Dementia progress graph ---"


echo ""

# ========================================
# Step 8: Patch figures for pathway analysis
# ========================================
echo "--- Step 8: Patch figures for pathway analysis ---"

render_html "pathway_analysis/05_patch_fig_and_make_table/01_create_suppl_table_and_extended_data.qmd"
render_html "pathway_analysis/05_patch_fig_and_make_table/02_patch_main_pathway_analysis.qmd"
render_html "pathway_analysis/05_patch_fig_and_make_table/03_patch_suppl_pathway_analysis.qmd"

# Deck-only: sole producer of the two fig_pres_* PNGs that

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
    echo "  - pathway_analysis/01_genes/output/                          (gene comparisons)"
    echo "  - pathway_analysis/02_gene_ontology/output/                  (GO enrichment results)"
    echo "  - pathway_analysis/03_transition_specific_GO_terms/output/   (transition-specific GO)"
    echo "  - pathway_analysis/04_function_categorization/output/        (function categories)"
    echo "  - pathway_analysis/05_patch_fig_and_make_table/output/       (figures & tables)"
fi
