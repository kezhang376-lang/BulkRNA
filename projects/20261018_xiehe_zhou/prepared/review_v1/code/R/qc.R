run_sample_qc <- function(counts, samples, output) {
  need(c("edgeR", "ggplot2", "pheatmap"))
  if (!setequal(colnames(counts), samples$sample_id) || anyDuplicated(samples$sample_id)) stopf("QC counts/metadata mismatch")
  counts <- counts[, samples$sample_id, drop = FALSE]
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  logcpm <- log2(edgeR::cpm(counts) + 1) # 保留原脚本描述性变换；不是 TMM，也不声称消除批次。
  write_matrix(logcpm, file.path(output, "log2_cpm_plus1.tsv"))
  write.csv(data.frame(sample_id = colnames(counts), library_counts = colSums(counts),
      detected_genes = colSums(counts > 0)), file.path(output, "library_summary.csv"), row.names = FALSE)
  data <- data.frame(expression = as.vector(logcpm),
                     sample = factor(rep(colnames(logcpm), each = nrow(logcpm)), levels = colnames(logcpm)))
  for (kind in c("boxplot", "violin")) {
    p <- ggplot2::ggplot(data, ggplot2::aes(sample, expression, fill = sample)) +
      ggplot2::labs(x = NULL, y = "log2(CPM + 1)") + ggplot2::theme_bw() +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1), legend.position = "none")
    p <- p + if (kind == "boxplot") ggplot2::geom_boxplot(outlier.shape = NA) else ggplot2::geom_violin()
    ggplot2::ggsave(file.path(output, paste0("sample_", kind, ".pdf")), p, width = 9, height = 7)
  }
  annotation <- data.frame(group = samples$group, row.names = samples$sample_id)
  correlation <- cor(logcpm)
  if (any(!is.finite(correlation))) stopf("Undefined sample correlation: constant expression profile")
  write.csv(correlation, file.path(output, "sample_correlation.csv"))
  save_heatmap(correlation, file.path(output, "sample_correlation.pdf"), annotation)
  variable <- apply(logcpm, 1, var) > 0
  if (sum(variable) < 2L) stopf("Too few variable genes for PCA")
  # 第一版显式使用 logCPM PCA，与原表达图相同尺度；不是 VST 或批次校正。
  pca <- prcomp(t(logcpm[variable, , drop = FALSE]), center = TRUE, scale. = FALSE)
  variance <- pca$sdev^2 / sum(pca$sdev^2)
  scores <- data.frame(sample_id = samples$sample_id, group = samples$group, pca$x[, 1:2, drop = FALSE])
  write.csv(scores, file.path(output, "pca_scores.csv"), row.names = FALSE)
  write.csv(data.frame(component = seq_along(variance), explained_fraction = variance),
            file.path(output, "pca_variance.csv"), row.names = FALSE)
  p <- ggplot2::ggplot(scores, ggplot2::aes(PC1, PC2, color = group, label = sample_id)) +
    ggplot2::geom_point(size = 3) + ggplot2::geom_text(vjust = -0.6, size = 3) + ggplot2::theme_bw() +
    ggplot2::labs(x = sprintf("PC1 (%.1f%%)", 100 * variance[1]), y = sprintf("PC2 (%.1f%%)", 100 * variance[2]))
  ggplot2::ggsave(file.path(output, "pca_logcpm.pdf"), p, width = 10, height = 7)
  if ("batch" %in% names(samples)) {
    scores$batch <- samples$batch
    write.csv(scores, file.path(output, "pca_with_batch.csv"), row.names = FALSE)
    p <- ggplot2::ggplot(scores, ggplot2::aes(PC1, PC2, color = batch, label = sample_id)) +
      ggplot2::geom_point(size = 3) + ggplot2::geom_text(vjust = -0.6, size = 3) + ggplot2::theme_bw()
    ggplot2::ggsave(file.path(output, "pca_batch.pdf"), p, width = 10, height = 7)
  }
  save_plot(file.path(output, "sample_clustering.pdf"), function() plot(hclust(dist(t(logcpm))), main = "Sample distance: logCPM"))
  invisible(logcpm)
}
