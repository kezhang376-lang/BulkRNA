#!/usr/bin/env Rscript
# 本地OrgDb基因ID + 人工counts；使用新包真实R入口，输出仅为兼容性测试。
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript smoke_R.R <bundle> <new_probe_dir>")
bundle <- normalizePath(args[1], mustWork = TRUE)
source(file.path(bundle, "code/R/common.R"))
runtime <- read_json(file.path(bundle, "runtime.json"))
verify_pod_account(runtime$config$kubernetes$account)
need(c("jsonlite", "DESeq2", "edgeR", "pheatmap", "ggplot2", "clusterProfiler", "enrichplot", "AnnotationDbi", "BiocParallel", runtime$config$enrichment$orgdb))
probe <- args[2]
if (file.exists(probe) || !dir.create(probe, recursive = TRUE)) stopf("Validation directory already exists or is not writable")
write_json(list(status = "running", kind = "compatibility_only"), file.path(probe, "status.json"))
tryCatch({
  samples <- read_metadata(file.path(bundle, "samples.tsv"), "\t")
  contrasts <- read_metadata(file.path(bundle, "contrasts.tsv"), "\t")
  db <- getExportedValue(runtime$config$enrichment$orgdb, runtime$config$enrichment$orgdb)
  set.seed(1081)
  ids <- sample(AnnotationDbi::keys(db, keytype = "ENSEMBL"), 1200L)
  means <- exp(runif(length(ids), log(20), log(1800)))
  dispersion <- 0.025 + 4 / means
  counts <- matrix(0L, nrow = length(ids), ncol = nrow(samples), dimnames = list(ids, samples$sample_id))
  for (j in seq_len(nrow(samples))) {
    mu <- means
    if (samples$group[j] == contrasts$treatment[1]) {
      mu[1:120] <- mu[1:120] * 4
      mu[121:240] <- mu[121:240] / 4
    }
    counts[, j] <- rnbinom(length(ids), mu = mu, size = 1 / dispersion)
  }
  write_matrix(counts, file.path(probe, "synthetic_counts.tsv"))
  file.copy(file.path(bundle, "samples.tsv"), file.path(probe, "samples.tsv"))
  file.copy(file.path(bundle, "contrasts.tsv"), file.path(probe, "contrasts.tsv"))
  runtime$compatibility_fixture <- list(kind = "simulated_counts", genes = length(ids), note = "No biological findings")
  runtime$config$paths$output_dir <- file.path(normalizePath(probe), "results")
  runtime$run_root <- file.path(runtime$config$paths$output_dir, runtime$run_id)
  runtime$config$input$type <- "counts"
  runtime$config$paths$counts_file <- file.path(normalizePath(probe), "synthetic_counts.tsv")
  runtime$config$analysis$fastp <- FALSE
  runtime$config$analysis$star <- FALSE
  runtime$config$analysis$featurecounts <- FALSE
  write_json(runtime, file.path(probe, "runtime.json"))
  logfile <- file.path(probe, "entrypoint.log")
  status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(file.path(bundle, "code/R/run_analysis.R")),
      shQuote(file.path(normalizePath(probe), "runtime.json")), "--execute"), stdout = logfile, stderr = logfile)
  if (status != 0L) stopf("R compatibility entrypoint failed (exit %d); see entrypoint.log", status)
  actual <- read_json(file.path(runtime$run_root, "gene_expr_data/status.json"))
  if (actual$status != "succeeded" || !file.exists(file.path(runtime$run_root, "gene_expr_data/report.html"))) stopf("R compatibility outputs incomplete")
  write_json(list(status = "succeeded", kind = "compatibility_only", genes = length(ids),
      note = "Synthetic QC/DE/GO results are not biological findings"), file.path(probe, "status.json"))
  cat("R_COMPATIBILITY_PASS", normalizePath(probe), "\n")
}, error = function(e) {
  write_json(list(status = "failed", kind = "compatibility_only", error = conditionMessage(e)), file.path(probe, "status.json"))
  stop(e)
})
