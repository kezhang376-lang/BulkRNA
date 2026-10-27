# 公共函数：不设置工作目录，不加载或清空全局环境。
stopf <- function(...) stop(sprintf(...), call. = FALSE)
need <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stopf("Missing R packages (no automatic installation): %s", paste(missing, collapse = ", "))
}
read_json <- function(path) {
  need("jsonlite")
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}
write_json <- function(x, path) {
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
}
write_utf8_lf <- function(lines, path) {
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
}
read_metadata <- function(path, sep = NULL) {
  if (!file.exists(path)) stopf("Missing metadata: %s", path)
  if (is.null(sep)) {
    header <- readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8")
    if (!length(header)) stopf("Empty metadata: %s", path)
    sep <- if (grepl("\t", header, fixed = TRUE)) "\t" else ","
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (length(lines)) lines[1] <- sub("^\ufeff", "", lines[1])
  x <- read.table(text = lines, header = TRUE, sep = sep, quote = '"', comment.char = "",
                  check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character",
                  na.strings = character())
  if (anyDuplicated(names(x)) || any(!nzchar(names(x)))) stopf("Invalid column names: %s", path)
  x
}
validate_metadata <- function(samples, contrasts) {
  if (any(vapply(c(samples, contrasts), function(x) anyNA(x) || any(grepl("[\r\n\t]", x)), logical(1)))) stopf("Missing values or embedded control characters in metadata")
  if (!all(c("sample_id", "group") %in% names(samples))) stopf("samples requires sample_id,group")
  if (!all(c("contrast_id", "treatment", "control") %in% names(contrasts))) stopf("contrasts requires contrast_id,treatment,control")
  safe <- function(x) all(grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", x) & !x %in% c(".", ".."))
  if (!nrow(samples) || !safe(samples$sample_id) || anyDuplicated(samples$sample_id)) stopf("sample_id must be nonempty, unique, and path-safe")
  if (any(!nzchar(samples$group) | trimws(samples$group) != samples$group)) stopf("Invalid group values")
  if (!nrow(contrasts) || !safe(contrasts$contrast_id) || anyDuplicated(contrasts$contrast_id)) stopf("Invalid contrast_id values")
  if (any(!contrasts$treatment %in% samples$group | !contrasts$control %in% samples$group |
          contrasts$treatment == contrasts$control)) stopf("Contrast groups missing or identical")
  invisible(TRUE)
}
read_counts <- function(path, samples) {
  x <- read.delim(path, check.names = FALSE, stringsAsFactors = FALSE, quote = "", comment.char = "")
  if (ncol(x) < 3L || !nrow(x) || names(x)[1] != "gene_id") stopf("Counts must be TSV: gene_id then >=2 sample columns")
  ids <- x[[1]]
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) stopf("Invalid/duplicate gene_id")
  if (anyDuplicated(names(x)[-1]) || !setequal(names(x)[-1], samples$sample_id)) stopf("Counts/metadata sample IDs differ")
  x <- x[, samples$sample_id, drop = FALSE]
  if (!all(vapply(x, is.numeric, logical(1)))) stopf("Counts contain nonnumeric values")
  m <- as.matrix(x)
  if (any(!is.finite(m)) || any(m < 0) || any(m != round(m)) || any(m > .Machine$integer.max)) stopf("Counts must be finite nonnegative integers in R integer range")
  if (any(colSums(m) == 0)) stopf("Zero-library sample")
  storage.mode(m) <- "integer"
  rownames(m) <- ids
  m
}
filter_counts <- function(counts, cfg, samples, design) {
  method <- cfg$method
  keep <- switch(method,
    legacy_nonzero_fraction = rowSums(counts > 0) >= floor(cfg$fraction * ncol(counts)),
    min_count_samples = rowSums(counts >= cfg$min_count) >= cfg$min_samples,
    none = rep(TRUE, nrow(counts)),
    stopf("Unsupported filtering.method: %s", method))
  if (sum(keep) < 2L) stopf("Filtering retained fewer than two genes")
  list(counts = counts[keep, , drop = FALSE], keep = keep)
}
write_matrix <- function(x, path) {
  write.table(data.frame(gene_id = rownames(x), x, check.names = FALSE), path,
              sep = "\t", quote = FALSE, row.names = FALSE)
}
save_plot <- function(path, draw, width = 9, height = 7) {
  grDevices::pdf(path, width = width, height = height)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
}
save_heatmap <- function(x, path, annotation = NULL, cluster_rows = TRUE, cluster_cols = TRUE, scale = "none") {
  if (!nrow(x) || !ncol(x) || any(!is.finite(x))) stopf("Invalid heatmap matrix: %s", path)
  p <- pheatmap::pheatmap(x, annotation_col = annotation, scale = scale,
      cluster_rows = cluster_rows && nrow(x) > 1L, cluster_cols = cluster_cols && ncol(x) > 1L,
      silent = TRUE)
  save_plot(path, function() { grid::grid.newpage(); grid::grid.draw(p$gtable) })
}
script_directory <- function() {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(arg) != 1L) stopf("Run this entrypoint with Rscript")
  dirname(normalizePath(sub("^--file=", "", arg), mustWork = TRUE))
}
