run_deseq2 <- function(counts, samples, contrasts, cfg, output) {
  need(c("DESeq2", "ggplot2"))
  validate_metadata(samples, contrasts)
  if (!setequal(colnames(counts), samples$sample_id)) stopf("DE counts/metadata mismatch")
  counts <- counts[, samples$sample_id, drop = FALSE]
  # 第一版仅接受加性列名公式，不允许任意 R 代码、交互项或隐式转换。
  if (!grepl("^~\\s*[A-Za-z][A-Za-z0-9_]*(\\s*\\+\\s*[A-Za-z][A-Za-z0-9_]*)*$", cfg$design)) stopf("Only additive design formulas are supported in v1")
  formula <- as.formula(cfg$design)
  variables <- all.vars(formula)
  if (!"group" %in% variables || !all(variables %in% names(samples))) stopf("Design requires group and existing metadata columns")
  cd <- samples
  rownames(cd) <- cd$sample_id
  for (v in variables) {
    if (any(!nzchar(cd[[v]]) | cd[[v]] %in% c("NA", "unknown"))) stopf("Unknown design values: %s", v)
    cd[[v]] <- factor(cd[[v]]) # 连续协变量第一版不支持，需显式扩展规范。
  }
  mm <- model.matrix(formula, cd)
  if (qr(mm)$rank < ncol(mm)) stopf("Design matrix is not full rank")
  if (nrow(mm) <= ncol(mm)) stopf("No residual degrees of freedom")
  if (!dir.create(output, recursive = TRUE, showWarnings = FALSE)) stopf("DE output exists or is not writable")
  write.csv(cd, file.path(output, "aligned_coldata.csv"), row.names = FALSE)
  write.csv(mm, file.path(output, "design_matrix.csv"))
  dds <- DESeq2::DESeqDataSetFromMatrix(counts, cd, formula)
  dds <- DESeq2::DESeq(dds, test = "Wald", fitType = cfg$fit_type,
                       minReplicatesForReplace = Inf, quiet = TRUE)
  actual_fit <- attr(DESeq2::dispersionFunction(dds), "fitType")
  if (!identical(actual_fit, cfg$fit_type)) stopf("DESeq2 changed dispersion fit from %s to %s; review and confirm before rerunning", cfg$fit_type, actual_fit)
  # 不自动替换离群计数；不 shrink；一次拟合用于全部比较。
  write_matrix(DESeq2::counts(dds, normalized = TRUE), file.path(output, "normalized_counts.tsv"))
  saveRDS(dds, file.path(output, "dds.rds"))
  summary <- list()
  for (i in seq_len(nrow(contrasts))) {
    contrast <- contrasts[i, ]
    folder <- file.path(output, contrast$contrast_id)
    dir.create(folder)
    result <- DESeq2::results(dds, contrast = c("group", contrast$treatment, contrast$control),
        alpha = cfg$fdr, pAdjustMethod = "BH", independentFiltering = TRUE, cooksCutoff = TRUE)
    tab <- data.frame(gene_id = rownames(result), as.data.frame(result), check.names = FALSE)
    tab$control_mean <- rowMeans(DESeq2::counts(dds, normalized = TRUE)[, cd$group == contrast$control, drop = FALSE])
    tab$treatment_mean <- rowMeans(DESeq2::counts(dds, normalized = TRUE)[, cd$group == contrast$treatment, drop = FALSE])
    tab$test_status <- ifelse(is.na(tab$pvalue), "pvalue_unavailable",
                              ifelse(is.na(tab$padj), "padj_unavailable", "tested"))
    tab$regulated <- ifelse(is.na(tab$padj), "not_evaluated", "normal")
    selected <- !is.na(tab$padj) & tab$padj < cfg$fdr & is.finite(tab$log2FoldChange)
    tab$regulated[selected & tab$log2FoldChange > cfg$log2fc_cutoff] <- "up"
    tab$regulated[selected & tab$log2FoldChange < -cfg$log2fc_cutoff] <- "down"
    tab <- tab[order(tab$padj, na.last = TRUE), ]
    write.csv(tab, file.path(folder, "all_genes.csv"), row.names = FALSE, na = "NA")
    write.csv(tab[tab$regulated %in% c("up", "down"), ], file.path(folder, "significant_genes.csv"), row.names = FALSE)
    saveRDS(result, file.path(folder, "result.rds"))
    summary[[i]] <- data.frame(contrast_id = contrast$contrast_id, treatment = contrast$treatment,
       control = contrast$control, tested = sum(tab$test_status == "tested"),
       up = sum(tab$regulated == "up"), down = sum(tab$regulated == "down"),
       not_evaluated = sum(tab$regulated == "not_evaluated"))
    save_plot(file.path(folder, "ma.pdf"), function() DESeq2::plotMA(result, alpha = cfg$fdr))
    plot_data <- tab[is.finite(tab$log2FoldChange) & !is.na(tab$padj), ]
    plot_data$minus_log10_padj <- -log10(pmax(plot_data$padj, .Machine$double.xmin))
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(log2FoldChange, minus_log10_padj, color = regulated)) +
      ggplot2::geom_point(alpha = 0.5, size = 1) +
      ggplot2::geom_vline(xintercept = c(-cfg$log2fc_cutoff, cfg$log2fc_cutoff), linetype = "dashed") +
      ggplot2::geom_hline(yintercept = -log10(cfg$fdr), linetype = "dashed") +
      ggplot2::scale_color_manual(values = c(normal = "grey60", up = "red3", down = "blue3")) +
      ggplot2::theme_bw() + ggplot2::labs(title = contrast$contrast_id, y = "-log10(padj)")
    ggplot2::ggsave(file.path(folder, "volcano.pdf"), p, width = 9, height = 7)
  }
  write.csv(do.call(rbind, summary), file.path(output, "contrast_summary.csv"), row.names = FALSE)
  invisible(dds)
}
