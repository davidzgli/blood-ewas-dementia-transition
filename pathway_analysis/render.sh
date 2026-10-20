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
#  3b. GO term recount (reviewer round; both thresholds): duplicate parents
#      (Rule 1) and redundancy-aware weights (Rule 2), read by Steps 4-8 and by
#      extended_data/03_biofunc_to_excel.qmd
#   4. Transition-specific GO terms (top_n 1000, 2000)
#   5. Assign function category (top_n 1000, 2000)
#   6. Analyze function category (top_n 1000, 2000)
#   7. Dementia progress graph
#   8. Patch figures for pathway analysis (main + supplementary)
#   9. GO hierarchy check (reviewer round; reads Steps 3-5 outputs;
#      no manuscript float)
#  10. GO category rule counts (reviewer round; reads Steps 4-5 outputs;
#      no manuscript float)
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
# Step 3b: GO term recount (reviewer round)
# ========================================
# ADJ-D-26-02882, R2.9 (authors' decision, 2026-10-09): drop a significant parent
# term whose genes are identical to those of a significant child (Rule 1), and
# weight each term significant in only one group by the share of its immediate GO
# relatives not significant in any group, its own or another (Rule 2; made
# redundancy-aware on 2026-10-13). Reads only the Step 3
# outputs; Steps 4-8 and extended_data/ read what it writes.
echo "--- Step 3b: GO term recount (reads Step 3 outputs) ---"

render_html "pathway_analysis/06_go_hierarchy/03_go_term_weights.qmd"

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

echo ""

# ========================================
# Step 9: GO hierarchy check (reviewer round)
# ========================================
# ADJ-D-26-02882, R2.9: does each transition-specific GO term have an ancestor
# or descendant that is significant in another group? Reads only saved outputs,
# with no enrichment re-run: top{1000,2000}_all_GO_results.rds (Step 3),
# top{1000,2000}_condition_specific_GO_terms.csv (Step 4) and
# top1000_condition_specific_GO_terms_auto_cat.xlsx (Step 5). No manuscript
# float; its numbers are quoted in the response letter and the revised text.
echo "--- Step 9: GO hierarchy check (reads Steps 3-5 outputs) ---"

render_html "pathway_analysis/06_go_hierarchy/01_go_hierarchy_check.qmd"

echo ""

# ========================================
# Step 10: GO category rule counts (reviewer round)
# ========================================
# ADJ-D-26-02882, R2.4: how often the ordered keyword rules in
# custom_func/assign_biofunc_category.R matched one, several or no categories,
# and how often the exclusions changed an assignment. Reads only saved outputs:
# top{1000,2000}_condition_specific_GO_terms.csv (Step 4) and
# top{1000,2000}_condition_specific_GO_terms_auto_cat.xlsx (Step 5). No
# manuscript float; its numbers are quoted in the response letter (R2.4 and
# Appendix E) and the revised Methods.
echo "--- Step 10: GO category rule counts (reads Steps 4-5 outputs) ---"

render_html "pathway_analysis/06_go_hierarchy/02_category_rule_counts.qmd"

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
    echo "  - pathway_analysis/06_go_hierarchy/output/                   (GO recount weights, hierarchy check and category rule counts, reviewer response)"
fi
