conda_lib <- "/opt/conda/lib/R/library"
site_lib  <- "/opt/conda/lib/R/site-library"
conda_pkgs <- list.files(conda_lib)
site_pkgs  <- list.files(site_lib)
duplicates <- intersect(conda_pkgs, site_pkgs)

keep_conda <- c("sf","terra","stringi","Rcpp","units","wk","s2")

to_remove_site <- intersect(duplicates, keep_conda)
if (length(to_remove_site) > 0) {
  unlink(file.path(site_lib, to_remove_site), recursive = TRUE)
  message("Removed site-library duplicates (kept conda binaries): ",
          paste(to_remove_site, collapse=", "))
}

to_remove_conda <- setdiff(duplicates, keep_conda)
if (length(to_remove_conda) > 0) {
  unlink(file.path(conda_lib, to_remove_conda), recursive = TRUE)
  message("Removed conda duplicates (kept CRAN/pak versions): ",
          paste(to_remove_conda, collapse=", "))
}
