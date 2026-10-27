# 独立可选函数：后续项目 custom/scripts 可 source 此文件。
# 不会被标准流程自动调用；表达矩阵必须已标准化并明确单位。
plot_selected_genes <- function(expression, samples, genes, output) {
  need(c("ggplot2", "pheatmap"))
  if (anyDuplicated(rownames(expression)) || anyDuplicated(colnames(expression))) stopf("Expression IDs must be unique")
  if (!setequal(colnames(expression), samples$sample_id)) stopf("Expression/metadata mismatch")
  expression <- expression[, samples$sample_id, drop = FALSE]
  genes <- unique(genes)
  if (anyNA(genes) || any(!nzchar(genes))) stopf("Invalid selected genes")
  if (dir.exists(output) || !dir.create(output, recursive = TRUE)) stopf("Custom output exists or cannot be created")
  writeLines(setdiff(genes, rownames(expression)), file.path(output, "missing_gene_ids.txt"))
  selected <- intersect(genes, rownames(expression))
  if (!length(selected)) {
    write_json(list(status = "no_matched_genes"), file.path(output, "status.json"))
    return(invisible(NULL))
  }
  x <- expression[selected, , drop = FALSE]
  anno <- data.frame(group = samples$group, row.names = samples$sample_id)
  save_heatmap(x, file.path(output, "selected_genes_heatmap.pdf"), anno, cluster_rows = FALSE)
  # 显式不附加 t 检验，避免与正式 DE 模型不一致；使用基因ID安全编号文件名。
  index <- data.frame(plot_id = seq_along(selected), gene_id = selected)
  write.csv(index, file.path(output, "plot_index.csv"), row.names = FALSE)
  for (i in seq_along(selected)) {
    data <- data.frame(sample_id = samples$sample_id, group = samples$group, expression = as.numeric(x[i, ]))
    p <- ggplot2::ggplot(data, ggplot2::aes(group, expression, fill = group)) +
      ggplot2::geom_boxplot(outlier.shape = NA) + ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.08, seed = 1)) +
      ggplot2::theme_bw() + ggplot2::labs(title = selected[i], y = "Input expression (caller-defined units)")
    ggplot2::ggsave(file.path(output, sprintf("gene_%04d.pdf", i)), p, width = 7, height = 5)
  }
  write_json(list(status = "succeeded", matched_genes = length(selected)), file.path(output, "status.json"))
}

plot_target_go <- function(gsea_rds, go_ids, output) {
  need(c("enrichplot", "ggplot2"))
  if (dir.exists(output) || !dir.create(output, recursive = TRUE)) stopf("GO output exists or cannot be created")
  gse <- readRDS(gsea_rds) # 调用者必须明确指定某个比较的结果文件。
  if (is.null(gse)) {
    write_json(list(status = "empty_gsea_result"), file.path(output, "status.json"))
    return(invisible(NULL))
  }
  if (!all(grepl("^GO:[0-9]{7}$", go_ids))) stopf("Invalid GO IDs")
  tab <- as.data.frame(gse)
  selected <- intersect(unique(go_ids), tab$ID)
  writeLines(setdiff(go_ids, selected), file.path(output, "missing_go_ids.txt"))
  write.csv(tab[tab$ID %in% selected, , drop = FALSE], file.path(output, "target_go.csv"), row.names = FALSE)
  for (id in selected) {
    p <- enrichplot::gseaplot2(gse, geneSetID = id, title = tab$Description[match(id, tab$ID)], pvalue_table = TRUE)
    save_plot(file.path(output, paste0(gsub(":", "_", id), ".pdf")), function() print(p))
  }
  write_json(list(status = if (length(selected)) "succeeded" else "no_matched_go", matched = length(selected)), file.path(output, "status.json"))
}
