# Function to add Gene Ontology results to Excel workbook
# Optimized for GO results data

add_go_to_excel <- function(wb, df, sheet_name, legend = "SD") {
  # Predefined variables
  from_row_predefined <- 3
  data_start_row <- from_row_predefined + 2
  
  # Create worksheet
  wb <- wb |>
    wb_add_worksheet(sheet_name, zoom = 120)
  
  # Format legend with fmt_txt() to make only "Supplementary Data X." bold
  # Use regex to match "Supplementary Data" followed by any number and a period
  if (grepl("Supplementary Data [0-9]+\\.", legend)) {
    # Extract the matched pattern
    supp_data_match <- regexpr("Supplementary Data [0-9]+\\.", legend)
    match_text <- regmatches(legend, supp_data_match)
    
    # Split the legend into parts
    parts <- strsplit(legend, match_text, fixed = TRUE)[[1]]
    
    # Create formatted text with only "Supplementary Data X." in bold
    formatted_legend <- paste0(
      fmt_txt(parts[1], bold = FALSE),
      fmt_txt(match_text, bold = TRUE),
      fmt_txt(parts[2], bold = FALSE)
    )
  } else {
    formatted_legend <- fmt_txt(legend, bold = FALSE)
  }
  
  # Add legend
  wb <- wb |>
    wb_merge_cells(dims = wb_dims(1, 1:ncol(df))) |>
    wb_add_data(x = formatted_legend, dims = wb_dims(1, 1)) |>
    wb_add_cell_style(
      dims = wb_dims(1, 1:ncol(df)),
      horizontal = "left",
      vertical = "top",
      wrap_text = TRUE
    ) |>
    wb_set_row_heights(rows = 1, heights = 100)  # Increased height for longer legend
  
  # Add data
  wb <- wb |>
    wb_add_data(
      dims = wb_dims(data_start_row, 1),
      col_names = FALSE,
      x = df
    )
  
  # Merged Headers
  merged_header_row <- from_row_predefined
  
  # Define column groups
  id_cols <- grep("^transition$|^ID$|^Description$", names(df))
  ratio_cols <- grep("^GeneRatio$|^BgRatio$", names(df))
  enrichment_cols <- grep("^RichFactor$|^FoldEnrichment$|^zScore$", names(df))
  stat_cols <- grep("^pvalue$|^p.adjust$|^qvalue$", names(df))
  gene_cols <- grep("^geneID$|^Count$", names(df))
  # New column group for function categorization
  func_cat_cols <- grep("^transition_specific$|^biofunc_category$", names(df))
  
  # Check if we have function categorization columns
  has_func_cat <- length(func_cat_cols) > 0
  
  # Calculate the number of columns for the original data (without function categorization)
  orig_cols <- setdiff(1:ncol(df), func_cat_cols)
  
  # Add merged headers for original columns
  wb <- wb |>
    wb_merge_cells(dims = wb_dims(merged_header_row, id_cols)) |>
    wb_add_data(sheet_name,
                x = "GO Term Information",
                dims = wb_dims(merged_header_row, id_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, ratio_cols)) |>
    wb_add_data(x = "Gene Ratios",
                dims = wb_dims(merged_header_row, ratio_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, enrichment_cols)) |>
    wb_add_data(x = "Enrichment Metrics",
                dims = wb_dims(merged_header_row, enrichment_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, stat_cols)) |>
    wb_add_data(x = "Statistical Significance",
                dims = wb_dims(merged_header_row, stat_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, gene_cols)) |>
    wb_add_data(x = "Gene Information",
                dims = wb_dims(merged_header_row, gene_cols[1]))
  
  # Add merged header for function categorization if columns exist
  if (has_func_cat) {
    wb <- wb |>
      wb_merge_cells(dims = wb_dims(merged_header_row, func_cat_cols)) |>
      wb_add_data(x = "Function Categorization",
                  dims = wb_dims(merged_header_row, func_cat_cols[1]))
  }
  
  # Set row height for header
  wb <- wb |> wb_set_row_heights(rows = merged_header_row, heights = 20)
  
  # Column Names
  column_name_row <- from_row_predefined + 1
  
  # Add column names
  wb <- wb |>
    wb_add_data(
      sheet_name,
      t(names(df)),
      dims = wb_dims(rows = column_name_row, cols = 1:ncol(df)),
      col_names = FALSE
    ) |>
    wb_set_row_heights(rows = column_name_row, heights = 40)
  
  # Format Header
  dims_header <- wb_dims(rows = 1:2,
                         cols = 1:ncol(df),
                         from_row = from_row_predefined)
  
  wb <- wb |>
    wb_add_cell_style(
      sheet = sheet_name,
      dims = dims_header,
      horizontal = "center",
      vertical = "center",
      wrap_text = "1"
    ) |>
    wb_add_font(
      dims = dims_header,
      name = "Arial",
      bold = TRUE,
      color = wb_color("black"),
      size = 12
    ) |>
    wb_add_fill(dims = dims_header, color = wb_color(name = "grey90"))
  
  # Format Specific Columns
  wb <- wb |>
    # Format p-values to scientific notation
    wb_add_numfmt(
      dims = wb_dims(
        rows = 1:nrow(df),
        cols = str_which(names(df), "pvalue|p.adjust|qvalue"),
        from_row = data_start_row
      ),
      numfmt = "0.00E+00"
    ) |>
    # Format enrichment metrics to 3 decimal places
    wb_add_numfmt(
      dims = wb_dims(
        rows = 1:nrow(df),
        cols = str_which(names(df), "RichFactor|FoldEnrichment|zScore"),
        from_row = data_start_row
      ),
      numfmt = "0.000"
    ) |>
    # Format Count as integer
    wb_add_numfmt(
      dims = wb_dims(
        rows = 1:nrow(df),
        cols = str_which(names(df), "Count"),
        from_row = data_start_row
      ),
      numfmt = "0"
    )
  
  # Borders
  border_col <- wb_color(theme = 1)
  border_sty <- "medium"
  
  # Add borders to each section
  wb <- wb |>
    # GO Term Information section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = id_cols,
        from_row = merged_header_row
      ),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty,
    ) |>
    # Gene Ratios section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = ratio_cols,
        from_row = merged_header_row
      ),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty,
    ) |>
    # Enrichment Metrics section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = enrichment_cols,
        from_row = merged_header_row
      ),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty,
    ) |>
    # Statistical Significance section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = stat_cols,
        from_row = merged_header_row
      ),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty,
    ) |>
    # Gene Information section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = gene_cols,
        from_row = merged_header_row
      ),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty,
    )
  
  # Add borders for Function Categorization section if columns exist
  if (has_func_cat) {
    wb <- wb |>
      wb_add_border(
        dims = wb_dims(
          rows = 1:(nrow(df) + 2),
          cols = func_cat_cols,
          from_row = merged_header_row
        ),
        top_color = border_col,
        top_border = border_sty,
        bottom_color = border_col,
        bottom_border = border_sty,
        left_color = border_col,
        left_border = border_sty,
        right_color = border_col,
        right_border = border_sty,
      )
  }
  
  # Prepare column widths
  # Default widths for standard columns
  std_widths <- c(
    12, # transition
    12, # ID
    40, # Description
    12, # GeneRatio
    12, # BgRatio
    12, # RichFactor
    12, # FoldEnrichment
    12, # zScore
    12, # pvalue
    12, # p.adjust
    12, # qvalue
    60, # geneID
    8   # Count
  )
  
  # Add widths for function categorization columns if they exist
  if (has_func_cat) {
    func_cat_widths <- c(
      15, # transition_specific
      25  # biofunc_category
    )
    # Create a vector of all column widths
    all_widths <- numeric(ncol(df))
    all_widths[orig_cols] <- std_widths[1:length(orig_cols)]
    all_widths[func_cat_cols] <- func_cat_widths[1:length(func_cat_cols)]
  } else {
    all_widths <- std_widths[1:ncol(df)]
  }
  
  # Freeze panes and set column widths
  wb <- wb |>
    wb_freeze_pane(first_active_row = data_start_row) |>
    wb_set_col_widths(
      sheet = sheet_name,
      cols = 1:ncol(df),
      widths = all_widths
    )
  
  # Add alternating row colors for better readability
  wb <- wb |>
    wb_add_fill(
      dims = wb_dims(
        rows = seq(data_start_row, data_start_row + nrow(df) - 1, by = 2),
        cols = 1:ncol(df)
      ),
      color = wb_color("grey95")
    )
  
  return(wb)
} 