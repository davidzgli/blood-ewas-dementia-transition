# Function to add summary table to Excel workbook
# Specifically designed for adding dmp_by_category summary statistics

add_summary_table_to_excel <- function(wb, df, sheet_name, start_cell = "U9") {
  
  # Parse start cell to get row and column numbers
  start_col <- which(LETTERS == substr(start_cell, 1, 1))
  start_row <- as.numeric(substr(start_cell, 2, nchar(start_cell)))
  
  # Define positions
  title_row <- start_row - 1
  header_row <- start_row
  data_row <- start_row + 1
  note_row <- start_row + 3  # Two rows below the table
  
  # Get column range
  end_col <- start_col + ncol(df) - 1
  
  # Add title
  wb <- wb |>
    wb_merge_cells(
      sheet = sheet_name,
      dims = wb_dims(rows = title_row, cols = start_col:end_col)
    ) |>
    wb_add_data(
      sheet = sheet_name,
      x = "Number of DMPs by dementia transition",
      dims = wb_dims(rows = title_row, cols = start_col)
    ) |>
    wb_add_font(
      sheet = sheet_name,
      dims = wb_dims(rows = title_row, cols = start_col:end_col),
      name = "Arial",
      bold = TRUE,
      size = 12
    ) |>
    wb_add_cell_style(
      sheet = sheet_name,
      dims = wb_dims(rows = title_row, cols = start_col:end_col),
      horizontal = "center",
      vertical = "center"
    )
  
  # Add column headers
  wb <- wb |>
    wb_add_data(
      sheet = sheet_name,
      x = t(names(df)),
      dims = wb_dims(rows = header_row, cols = start_col:end_col),
      col_names = FALSE
    )
  
  # Add data
  wb <- wb |>
    wb_add_data(
      sheet = sheet_name,
      x = t(as.numeric(df[1, ])),
      dims = wb_dims(rows = data_row, cols = start_col:end_col),
      col_names = FALSE
    )
  
  # Format headers
  wb <- wb |>
    wb_add_font(
      sheet = sheet_name,
      dims = wb_dims(rows = header_row, cols = start_col:end_col),
      name = "Arial",
      bold = TRUE,
      color = wb_color("black"),
      size = 12
    ) |>
    wb_add_fill(
      sheet = sheet_name,
      dims = wb_dims(rows = header_row, cols = start_col:end_col),
      color = wb_color(name = "grey90")
    ) |>
    wb_add_cell_style(
      sheet = sheet_name,
      dims = wb_dims(rows = header_row, cols = start_col:end_col),
      horizontal = "center",
      vertical = "center"
    )
  
  # Format data cells
  wb <- wb |>
    wb_add_font(
      sheet = sheet_name,
      dims = wb_dims(rows = data_row, cols = start_col:end_col),
      name = "Arial",
      size = 12
    ) |>
    wb_add_cell_style(
      sheet = sheet_name,
      dims = wb_dims(rows = data_row, cols = start_col:end_col),
      horizontal = "center",
      vertical = "center"
    ) |>
    wb_add_numfmt(
      sheet = sheet_name,
      dims = wb_dims(rows = data_row, cols = start_col:end_col),
      numfmt = "#,##0"
    )
  
  # Add borders around the table
  border_col <- wb_color(theme = 1)
  border_sty <- "medium"
  
  wb <- wb |>
    wb_add_border(
      sheet = sheet_name,
      dims = wb_dims(rows = header_row:data_row, cols = start_col:end_col),
      top_color = border_col,
      top_border = border_sty,
      bottom_color = border_col,
      bottom_border = border_sty,
      left_color = border_col,
      left_border = border_sty,
      right_color = border_col,
      right_border = border_sty
    )
  
  # Set column widths for better display of column names
  wb <- wb |>
    wb_set_col_widths(
      sheet = sheet_name,
      cols = start_col:end_col,
      widths = c(15, 15, 16, 14, 12)  # Adjusted widths for each column
    )
  
  # Add explanatory note
  note_text <- "Note: The number of significant CpG sites for each dementia transition were counted as the CpGs whose -log10 p-value > 8 (Bonferroni corrected significance level)."
  
  wb <- wb |>
    wb_merge_cells(
      sheet = sheet_name,
      dims = wb_dims(rows = note_row, cols = start_col:end_col)
    ) |>
    wb_add_data(
      sheet = sheet_name,
      x = note_text,
      dims = wb_dims(rows = note_row, cols = start_col)
    ) |>
    wb_add_cell_style(
      sheet = sheet_name,
      dims = wb_dims(rows = note_row, cols = start_col:end_col),
      horizontal = "left",
      vertical = "top",
      wrap_text = TRUE
    ) |>
    wb_add_font(
      sheet = sheet_name,
      dims = wb_dims(rows = note_row, cols = start_col:end_col),
      name = "Arial",
      size = 11
    )
  
  return(wb)
} 