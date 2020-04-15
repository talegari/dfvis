.onLoad <- function(...) {
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    vctrs::s3_register("ggplot2::autoplot", "data.frame")
  }
}
