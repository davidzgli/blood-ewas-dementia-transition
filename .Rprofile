# renv activation
# Guarded on file.exists(): renv/ is present in the public release repo but not
# in this one, and an error here would halt R for every session in the project.
if (file.exists("renv/activate.R")) source("renv/activate.R")

# Load libraries
# Also guarded: on a fresh clone the project library is empty, so an unguarded
# p_load() would halt R -- including the renv::restore() that would fix it.
if (requireNamespace("pacman", quietly = TRUE) &&
    requireNamespace("ggplot2", quietly = TRUE)) {

  pacman::p_load(tidyverse, here, janitor, glue, tictoc, install = FALSE)

  # Set themes
  theme_old <- ggplot2::theme_set(ggplot2::theme_bw())
  ggplot2::theme_update(
    panel.grid = ggplot2::element_blank(),
    axis.text.x = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
    axis.text.y = ggplot2::element_text(size = 12),
    axis.title = ggplot2::element_text(size = 14),
    strip.text = ggplot2::element_text(size = 16, face = "bold")
  )

} else {
  message(
    "Project library not ready. Run:  renv::restore()\n",
    "See README.md -> Installation."
  )
}
