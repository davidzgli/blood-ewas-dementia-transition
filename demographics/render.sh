#!/bin/bash
# render.sh - Render demographics tables and baseline characteristics
#
# Two steps:
#   Step 1: Four independent files (no ordering dependencies)
#     1. Dementia category table
#     2. Covariate table
#     3. Baseline characteristics Excel
#     4. Follow-up timeline figure (reviewer round, R1.3)
#   Step 2: Table 2 baseline characteristics by group (reviewer round, R1.2;
#           reads the Step 1 outputs of files 1-3)
#
# Usage: bash demographics/render.sh

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
echo "Demographics Render Script"
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
# Step 1: Independent files
# ========================================
echo "--- Step 1: Demographics tables, baseline characteristics and follow-up timeline ---"

render_html "demographics/01_dementia_category_table.qmd"
render_html "demographics/02_covariate_table.qmd"
render_html "demographics/03_baseline_characteristics_excel.qmd"

# Reviewer round (ADJ-D-26-02882, R1.3): study timeline and follow-up per
# group, drawn as a figure. Reads only data/.
render_html "demographics/04_followup_timeline.qmd"

echo ""

# ========================================
# Step 2: Table 2 (reads Step 1 outputs)
# ========================================
echo "--- Step 2: Table 2 baseline characteristics (reads Step 1 outputs) ---"

# Reviewer round (ADJ-D-26-02882, R1.2): merges the covariate and baseline
# tables into one flextable for the Word Table 2. Reads
# dementia_category_table_base.rds (01), covariate_table_by_dementia_transition.rds
# (02), baseline_characteristics_by_dementia_no_apoe.rds and
# baseline_characteristics_by_dementia.xlsx (03).
render_html "demographics/05_table2_baseline.qmd"

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
    echo "  - demographics/output/*.png   (table images, follow-up timeline figure)"
    echo "  - demographics/output/*.xlsx  (baseline characteristics)"
    echo "  - demographics/output/*.rds   (table objects, Table 2 flextable, follow-up timeline data)"
    echo "  - demographics/output/table2_baseline_by_group_preview.docx  (Table 2 Word preview)"
fi
