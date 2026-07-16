#' @title theme_main_fig
#' @description A theme for the main figure with ggtext support
#' @param base_size The base size for the theme
#' @param base_family The base family for the theme
#' @return A ggplot2 theme
#' @export
#' @note Requires ggtext package for element_markdown() and element_textbox()

theme_main_fig <- function(base_size = 8, base_family = "sans") {
  theme_bw(base_size = base_size, base_family = base_family) +
    theme(
      # Remove backgrounds and grids
      panel.background = element_blank(),
      plot.background = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),

      # Axis formatting (using element_markdown for HTML/markdown support)
      axis.line = element_line(color = "black", linewidth = 0.4),
      axis.ticks = element_line(color = "black", linewidth = 0.4),
      axis.text = ggtext::element_markdown(
        size = rel(0.85),
        color = "black"
      ),
      axis.text.x = ggtext::element_markdown(
        size = rel(0.85),
        color = "black"
      ),
      axis.text.y = ggtext::element_markdown(
        size = rel(0.85),
        color = "black"
      ),
      axis.title = ggtext::element_markdown(
        size = base_size,
        color = "black"
      ),
      axis.title.x = ggtext::element_markdown(
        size = base_size,
        color = "black"
      ),
      axis.title.y = ggtext::element_markdown(
        size = base_size,
        color = "black"
      ),

      # Legend formatting (using element_markdown for HTML/markdown support)
      legend.background = element_blank(),
      legend.key = element_blank(),
      legend.position = "right",
      legend.title = ggtext::element_markdown(
        size = base_size,
        color = "black"
      ),
      legend.text = ggtext::element_markdown(
        size = rel(0.85),
        color = "black"
      ),

      # Title and subtitle (using element_markdown for HTML/markdown support)
      plot.title = ggtext::element_markdown(
        size = base_size * 1.2,
        color = "black",
        hjust = 0
      ),
      plot.subtitle = ggtext::element_markdown(
        size = base_size,
        color = "grey50",
        hjust = 0
      ),

      # Facet strip formatting (using element_textbox_simple for HTML support)
      strip.text = ggtext::element_textbox_simple(
        size = rel(0.85),
        color = "black",
        halign = 0.5,
        lineheight = 1.2
      ),
      strip.text.x = ggtext::element_textbox_simple(
        size = rel(0.85),
        color = "black",
        halign = 0.5,
        lineheight = 1.2,
        margin = margin(4, 2, 2, 2)
      ),
      strip.text.y = ggtext::element_textbox_simple(
        size = rel(0.85),
        color = "black",
        halign = 0.5,
        orientation = "right-rotated",
        lineheight = 1.2,
        margin = margin(2, 4, 2, 2)
      ),

      # Margins
      plot.margin = margin(2, 2, 2, 2, "mm")
    )
}

#' @title rescale_layer_params
#' @description Scale explicit geom aesthetic params (size, linewidth, stroke) in
#'   a ggplot object. Useful when plots designed for large canvases are rendered
#'   at publication column width, causing elements to appear disproportionately
#'   large. Leaves size.unit = "pt" text unchanged by default since 6pt is
#'   already at publication minimum.
#' @param plot A ggplot object
#' @param size_scale Multiplier for mm-based `size` params (default 1 = no change)
#' @param linewidth_scale Multiplier for `linewidth` and `stroke` params
#'   (defaults to `size_scale`)
#' @param pt_scale Optional multiplier for `size` when `size.unit = "pt"`.
#'   NULL (default) leaves pt-based text unchanged.
#' @return The modified ggplot object
#' @export

rescale_layer_params <- function(plot,
                                 size_scale = 1,
                                 linewidth_scale = size_scale,
                                 pt_scale = NULL) {
  for (i in seq_along(plot$layers)) {
    ap <- plot$layers[[i]]$aes_params
    uses_pt <- identical(ap$size.unit, "pt") ||
               identical(plot$layers[[i]]$geom_params$size.unit, "pt")
    if (!is.null(ap$size)) {
      if (uses_pt && !is.null(pt_scale)) {
        plot$layers[[i]]$aes_params$size <- ap$size * pt_scale
      } else if (!uses_pt) {
        plot$layers[[i]]$aes_params$size <- ap$size * size_scale
      }
    }
    if (!is.null(ap$linewidth)) {
      plot$layers[[i]]$aes_params$linewidth <- ap$linewidth * linewidth_scale
    }
    if (!is.null(ap$stroke)) {
      plot$layers[[i]]$aes_params$stroke <- ap$stroke * linewidth_scale
    }
  }
  plot
}

#' @title set_pub_geom_defaults
#' @description Set publication-ready geom defaults for figures saved at display size
#' @export
set_pub_geom_defaults <- function() {
  update_geom_defaults("point", list(size = 1))
  update_geom_defaults("boxplot", list(linewidth = 0.4, outlier.size = 0.5))
  update_geom_defaults("text", list(size = 2.5))
  update_geom_defaults("label", list(size = 2.5))
}
