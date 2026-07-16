# Function to add DMP CG sites data to Excel workbook
# Specifically optimized for the 403 DMP sites data

add_cg_to_excel <- function(wb, df, sheet_name, legend = "SD") {
  # Predefined variables
  from_row_predefined <- 3
  data_start_row <- from_row_predefined + 2
  
  # Create worksheet
  wb <- wb |>
    wb_add_worksheet(sheet_name, zoom = 120)
  
  # Format legend - use as-is if already fmt_txt, otherwise wrap in fmt_txt
  if (inherits(legend, "fmt_txt")) {
    formatted_legend <- legend
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
  nlog10_cols <- grep("^nlog10_p", names(df))
  estimate_cols <- grep("^estimate", names(df))
  anno_cols <- grep("^UCSC_|^great_anno", names(df))
  coord_cols <- grep("^rank|^cg|^chr|^pos", names(df))
  wb <- wb |>
    wb_merge_cells(dims = wb_dims(merged_header_row, nlog10_cols)) |>
    wb_add_data(sheet_name,
                x = "negative log10 pvalue",
                dims = wb_dims(merged_header_row, nlog10_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, estimate_cols)) |>
    wb_add_data(x = "effect size",
                dims = wb_dims(merged_header_row, estimate_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, anno_cols)) |>
    wb_add_data(x = "gene annotation",
                dims = wb_dims(merged_header_row, anno_cols[1])) |>
    wb_merge_cells(dims = wb_dims(merged_header_row, coord_cols)) |>
    wb_add_data(x = "genomic coordinates",
                dims = wb_dims(merged_header_row, coord_cols[1])) |>
    wb_set_row_heights(rows = merged_header_row, heights = 20)
  
  # Column Names
  column_name_row <- from_row_predefined + 1
  modified_names <- names(df) |>
    str_remove("nlog10_p_value_|estimate_") |>
    str_replace_all(c("UCSC_" = "UCSC ", "great_anno" = "GREAT software"))
  
  wb <- wb |>
    wb_add_data(
      sheet_name,
      t(modified_names),
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
    # Format p-values and estimates to 3 decimal places
    wb_add_numfmt(
      dims = wb_dims(
        rows = 1:nrow(df),
        cols = str_which(names(df), "nlog10_p_value_|estimate_"),
        from_row = data_start_row
      ),
      numfmt = "0.000"
    ) |>
    # Format position as integer with thousands separator
    wb_add_numfmt(
      dims = wb_dims(
        rows = 1:nrow(df),
        cols = str_which(names(df), "pos"),
        from_row = data_start_row
      ),
      numfmt = "#,##0"
    )
  
  # Borders
  border_col <- wb_color(theme = 1)
  border_sty <- "medium"
  
  # Add borders to each section
  wb <- wb |>
    # Negative log10 pvalue section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = nlog10_cols,
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
    # Effect size section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = estimate_cols,
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
    # Gene annotation section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = anno_cols,
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
    # Genomic coordinates section
    wb_add_border(
      dims = wb_dims(
        rows = 1:(nrow(df) + 2),
        cols = coord_cols,
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

  # Freeze panes and set column widths
  wb <- wb |>
    wb_freeze_pane(first_active_row = data_start_row) |>
    wb_set_col_widths(
      sheet = sheet_name,
      cols = 1:ncol(df),
      # Adjust column widths based on content type
      # rank(6), cg(12), chr(6), pos(12), UCSC_RefGene(20), great_anno(30), p-values and estimates(8 each)
      widths = c(6, 12, 6, 12, 20, 30, rep(8, length(c(nlog10_cols, estimate_cols))))
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
  
  # Highlight significant values (p-value > 8) with conditional formatting
  for (col in nlog10_cols) {
    wb <- wb |>
      wb_add_conditional_formatting(
        dims = wb_dims(
          rows = 1:nrow(df),
          cols = col,
          from_row = data_start_row
        ),
        rule = ">8",
        style = create_dxfs_style(
          font_color = wb_color("red"),
          bold = TRUE
        )
      )
  }
  
  return(wb)
} 