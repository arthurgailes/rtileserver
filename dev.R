# Development workflow script for rtileserver
# Usage: source("dev.R") then run commands like dev_test()

# === Core workflows ===
dev_test <- function() {
  devtools::load_all()
  devtools::document()
  tinytest::test_all()
}

dev_check <- function() {
  dev_test()
  devtools::check()
}

# currently only works fresh - not if loaded already
dev_build <- function() tinytest::build_install_test()

# === Individual commands ===
dev_doc <- function() devtools::document()
dev_test <- function() tinytest::test_all()
dev_check <- function() devtools::check()
dev_install <- function() devtools::install()
dev_load <- function() devtools::load_all()

dev_style <- function() styler::style_pkg()
dev_lint <- function() lintr::lint_package()

# === Testing helpers ===
dev_test_file <- function(file) {
  if (!grepl("^inst/", file)) file <- file.path("inst/tinytest", file)
  tinytest::run_test_file(file)
}
