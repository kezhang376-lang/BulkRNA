# 每个比较单独读取完整 DE 表；注释永不回写/扩增基因级 DE 主表。
run_enrichment <- function(contrasts, runtime, de_dir, output) {
  need(c("clusterProfiler", "AnnotationDbi", "ggplot2", "enrichplot"))
  cfg <- runtime$config$enrichment
  need(cfg$orgdb)
  orgdb <- getExportedValue(cfg$orgdb, cfg$orgdb)
  available <- AnnotationDbi::keys(orgdb, keytype = cfg$key_type)
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(nrow(contrasts))) {
    contrast_id <- contrasts$contrast_id[i]
    tab <- read.csv(file.path(de_dir, contrast_id, "all_genes.csv"), check.names = FALSE)
    if (anyDuplicated(tab$gene_id)) stopf("Duplicate gene IDs in DE table: %s", contrast_id)
    folder <- file.path(output, contrast_id)
    dir.create(folder)
    mapped <- tab$gene_id %in% available
    write.csv(data.frame(gene_id = tab$gene_id, maps_to_orgdb = mapped),
              file.path(folder, "annotation_mapping.csv"), row.names = FALSE)
    if (!any(mapped)) {
      write_json(list(status = "no_mapped_genes", note = "Review species/ID version; no ID rewriting or threshold change applied"), file.path(folder, "status.json"))
      next
    }
    symbols <- AnnotationDbi::select(orgdb, keys = intersect(tab$gene_id, available),
                                      keytype = cfg$key_type, columns = "SYMBOL")
    write.csv(symbols, file.path(folder, "id_symbol_mapping.csv"), row.names = FALSE)
    # 结果表保留全部返回项；显著项单独导出和绘图。
    export <- function(object, prefix) {
      saveRDS(object, paste0(prefix, ".rds"))
      table <- if (is.null(object)) data.frame(ID = character(), Description = character(),
          pvalue = numeric(), p.adjust = numeric()) else as.data.frame(object)
      write.csv(table, paste0(prefix, "_all.csv"), row.names = FALSE)
      sig <- table[!is.na(table$p.adjust) & table$p.adjust < cfg$fdr, , drop = FALSE]
      write.csv(sig, paste0(prefix, "_significant.csv"), row.names = FALSE)
      write_json(list(status = if (nrow(sig)) "results" else "no_significant_terms", terms = nrow(sig)), paste0(prefix, "_status.json"))
      if (nrow(sig)) {
        shown <- object
        shown@result <- shown@result[shown@result$ID %in% sig$ID, , drop = FALSE]
        p <- enrichplot::dotplot(shown, showCategory = min(cfg$show_category, nrow(sig)))
        ggplot2::ggsave(paste0(prefix, "_dotplot.pdf"), p, width = 10, height = 8)
      }
    }
    if (isTRUE(runtime$config$analysis$gsea)) {
      score <- tab[[cfg$gsea_rank]]
      keep <- mapped & is.finite(score)
      ranks <- score[keep]
      names(ranks) <- tab$gene_id[keep]
      # 分数相同按原始ID排序，保留 ties 并报告，不抖动数值。
      ranks <- ranks[order(-ranks, names(ranks))]
      if (length(ranks) < cfg$min_gs_size || !any(ranks > 0) || !any(ranks < 0)) stopf("Insufficient/totally one-sided GSEA ranks: %s", contrast_id)
      write.csv(data.frame(gene_id = names(ranks), score = ranks), file.path(folder, "go_gsea_ranks.csv"), row.names = FALSE)
      write_json(list(total = nrow(tab), used = length(ranks), tied_scores = sum(duplicated(ranks)),
                      statistic = cfg$gsea_rank), file.path(folder, "go_gsea_rank_diagnostics.json"))
      set.seed(cfg$seed)
      # backend 明确为 fgsea；不传旧版 nPerm，避免静默切换算法。
      gse <- clusterProfiler::gseGO(geneList = ranks, OrgDb = orgdb, keyType = cfg$key_type,
          ont = cfg$ontology, minGSSize = cfg$min_gs_size, maxGSSize = cfg$max_gs_size,
          pvalueCutoff = 1, pAdjustMethod = "BH", by = "fgsea", eps = cfg$eps,
          seed = TRUE, verbose = FALSE)
      export(gse, file.path(folder, "go_gsea"))
    }
    if (isTRUE(runtime$config$analysis$go_enrichment)) {
      universe <- tab$gene_id[mapped & !is.na(tab$padj)]
      for (direction in c("up", "down")) {
        genes <- intersect(tab$gene_id[tab$regulated == direction], universe)
        object <- if (!length(genes)) NULL else clusterProfiler::enrichGO(gene = genes,
            universe = universe, OrgDb = orgdb, keyType = cfg$key_type, ont = cfg$ontology,
            minGSSize = cfg$min_gs_size, maxGSSize = cfg$max_gs_size,
            pAdjustMethod = "BH", pvalueCutoff = 1, qvalueCutoff = 1, readable = FALSE)
        export(object, file.path(folder, paste0("go_ora_", direction)))
      }
      writeLines(universe, file.path(folder, "go_ora_universe.txt"))
    }
  }
}
