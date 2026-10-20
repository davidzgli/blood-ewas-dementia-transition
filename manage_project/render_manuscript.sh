#!/bin/bash
# render_manuscript.sh - Render all Quarto files for EWAS dementia manuscript
#
# Calls per-directory render.sh scripts in dependency order.
# Three independent analysis pipelines converge at the manuscript layer.
# One reviewer-round check reads the outputs of all three pipelines, so it
# runs as its own stage after Pipeline C (see REVIEWER CHECKS below).
#
# Run from the project root directory.
#
# Usage: bash manage_project/render_manuscript.sh [OPTIONS]
#
# Options:
#   --pipeline-a       Pipeline A: demographics, DMP, validation, normal2mci, stable_mci
#   --pipeline-b       Pipeline B: UMAP, VAE, VAE_UMAP_comb, APOE
#   --pipeline-c       Pipeline C: pathway_analysis, extended_data
#   --reviewer-checks  Cross-pipeline reviewer-round check (requires Pipelines A, B and C complete)
#   --manuscript       Manuscript rendering (requires all pipelines complete)
#   --all              Run everything (default)

set -e  # Exit on first error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
DIR_TOTAL=0
DIR_SUCCESS=0
DIR_FAILED=0

# Parse arguments
RUN_A=false
RUN_B=false
RUN_C=false
RUN_REV=false
RUN_MS=false

if [[ $# -eq 0 ]] || [[ "$1" == "--all" ]]; then
    RUN_A=true
    RUN_B=true
    RUN_C=true
    RUN_REV=true
    RUN_MS=true
else
    for arg in "$@"; do
        case "$arg" in
            --pipeline-a) RUN_A=true ;;
            --pipeline-b) RUN_B=true ;;
            --pipeline-c) RUN_C=true ;;
            --reviewer-checks) RUN_REV=true ;;
            --manuscript) RUN_MS=true ;;
            *) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        esac
    done
fi

run_dir_script() {
    local script="$1"
    local label="$2"
    DIR_TOTAL=$((DIR_TOTAL + 1))
    echo -e "${YELLOW}>>> Running:${NC} $script ($label)"
    if bash "$script"; then
        DIR_SUCCESS=$((DIR_SUCCESS + 1))
        echo -e "${GREEN}>>> Completed:${NC} $script"
    else
        DIR_FAILED=$((DIR_FAILED + 1))
        echo -e "${RED}>>> FAILED:${NC} $script"
        return 1
    fi
    echo ""
}

# A single notebook whose inputs span pipelines, so it cannot live in any one
# directory's render.sh. Counted with the directory scripts.
run_qmd_file() {
    local file="$1"
    local label="$2"
    DIR_TOTAL=$((DIR_TOTAL + 1))
    echo -e "${YELLOW}>>> Rendering:${NC} $file ($label)"
    if quarto render "$file" --to html; then
        DIR_SUCCESS=$((DIR_SUCCESS + 1))
        echo -e "${GREEN}>>> Completed:${NC} $file"
    else
        DIR_FAILED=$((DIR_FAILED + 1))
        echo -e "${RED}>>> FAILED:${NC} $file"
        return 1
    fi
    echo ""
}

echo "========================================"
echo "EWAS Manuscript Render Script"
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
# PIPELINE A: Demographics / DMP / Validation / Normal-to-MCI / Stable-MCI
# ========================================

if [[ "$RUN_A" == true ]]; then

echo -e "${CYAN}=== PIPELINE A: Demographics / DMP / Validation / Normal-to-MCI / Stable-MCI ===${NC}"
echo ""

run_dir_script "demographics/render.sh" "demographics tables"
run_dir_script "dmp/render.sh" "DMP analysis"
run_dir_script "validation/render.sh" "validation pipeline"
run_dir_script "normal2mci_focused/render.sh" "normal-to-MCI analysis"
run_dir_script "stable_mci_focused/render.sh" "stable-MCI analysis"

fi  # end Pipeline A

# ========================================
# PIPELINE B: UMAP / VAE / VAE_UMAP_comb / APOE
# ========================================

if [[ "$RUN_B" == true ]]; then

echo -e "${CYAN}=== PIPELINE B: UMAP / VAE / VAE_UMAP_comb / APOE ===${NC}"
echo ""

run_dir_script "UMAP/lite/render.sh" "UMAP embedding + DPS"
run_dir_script "VAE/lite/render.sh" "VAE embedding + DPS + methodology figures"
run_dir_script "VAE_UMAP_comb/render.sh" "cross-method analysis"
run_dir_script "APOE/render.sh" "APOE analysis"

fi  # end Pipeline B

# ========================================
# PIPELINE C: Pathway Analysis / Extended Data
# ========================================

if [[ "$RUN_C" == true ]]; then

echo -e "${CYAN}=== PIPELINE C: Pathway Analysis / Extended Data ===${NC}"
echo ""

run_dir_script "pathway_analysis/render.sh" "pathway analysis"
run_dir_script "extended_data/render.sh" "extended data tables"

fi  # end Pipeline C

# ========================================
# REVIEWER CHECKS: cross-pipeline (ADJ-D-26-02882 reviewer round)
# ========================================
# normal2mci_focused/05_zero_pvalue_check.qmd recomputes every correlation and
# permutation P printed as 0 (R1.5/R2.7). It is not in
# normal2mci_focused/render.sh because it reads saved outputs of all three
# pipelines: A (normal2mci_focused/, validation/, stable_mci_focused/),
# B (UMAP/lite/, VAE/lite/, VAE_UMAP_comb/, APOE/) and C (pathway_analysis/
# 01_genes/ and 04_function_categorization/ figure objects). Pipeline C is the
# last of those, so the check runs here. It runs before the manuscript because
# it stops when a figure object is neither exactly as submitted nor free of
# zero P labels (a half-relabelled object), or when any other figure object
# prints a zero P label; a failure then halts the run before the manuscript
# embeds that figure. Nothing in the manuscript reads its output
# (normal2mci_focused/output/zero_pvalue_table.rds).

if [[ "$RUN_REV" == true ]]; then

echo -e "${CYAN}=== REVIEWER CHECKS: cross-pipeline (reads Pipelines A, B and C) ===${NC}"
echo ""

run_qmd_file "normal2mci_focused/05_zero_pvalue_check.qmd" "zero P-value check"

fi  # end Reviewer checks

# ========================================
# MANUSCRIPT: Final Products (PDF + DOCX)
# ========================================

if [[ "$RUN_MS" == true ]]; then

echo -e "${CYAN}=== MANUSCRIPT: Final Products (PDF + DOCX) ===${NC}"
echo ""

run_dir_script "ms/render.sh" "manuscript PDF + DOCX"

fi  # end Manuscript

echo "========================================"
echo "Render Complete"
echo "========================================"
echo -e "Directory scripts and files: $DIR_TOTAL | ${GREEN}Success: $DIR_SUCCESS${NC} | ${RED}Failed: $DIR_FAILED${NC}"
echo ""

if [[ $DIR_FAILED -gt 0 ]]; then
    echo -e "${RED}Some directory scripts failed. Check output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All directory scripts completed successfully!${NC}"
    echo ""
    echo "Output locations:"
    echo "  Pipeline A:"
    echo "    - demographics/output/*"
    echo "    - dmp/output/*"
    echo "    - dmp/patch_figures/output/*"
    echo "    - validation/output/*"
    echo "    - validation/patch_figures/output/*"
    echo "    - normal2mci_focused/output/*"
    echo "    - normal2mci_focused/patch_figures/output/*"
    echo "    - stable_mci_focused/output/*"
    echo "    - stable_mci_focused/patch_figures/output/*"
    echo "  Pipeline B:"
    echo "    - UMAP/lite/*/output/*"
    echo "    - VAE/lite/*/output/*"
    echo "    - VAE/lite/VAE_graph/output/*"
    echo "    - VAE_UMAP_comb/output/*"
    echo "    - VAE_UMAP_comb/patch_figures/output/*"
    echo "    - APOE/output/*"
    echo "    - APOE/patch_figures/output/*"
    echo "  Pipeline C:"
    echo "    - pathway_analysis/*/output/*"
    echo "    - extended_data/output/*"
    echo "  Reviewer checks:"
    echo "    - normal2mci_focused/output/zero_pvalue_table.rds"
    echo "  Manuscript:"
    echo "    - ms/fig_tbl/*.pdf, *.docx"
    echo "    - ms/write-ms/*.pdf, *.docx"
fi
