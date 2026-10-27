# 明确使用fgsea多层算法。新版clusterProfiler::gseGO可能忽略by/eps/BPPARAM，
# 因此直接从同一OrgDb的GOALL映射建立集合，不依赖其会变动的后端包装器。
go_gsea_fgsea <- function(ranks, orgdb, cfg) {
  need(c("fgsea", "GO.db", "qvalue", "BiocParallel", "DOSE"))
  mapping <- AnnotationDbi::select(orgdb, keys = names(ranks), keytype = cfg$key_type,
                                  columns = c("GOALL", "ONTOLOGYALL"))
  mapping <- mapping[!is.na(mapping$GOALL) & !is.na(mapping$ONTOLOGYALL), , drop = FALSE]
  if (cfg$ontology != "ALL") mapping <- mapping[mapping$ONTOLOGYALL == cfg$ontology, , drop = FALSE]
  godb <- getExportedValue("GO.db", "GO.db")
  mapping <- mapping[mapping$GOALL %in% AnnotationDbi::keys(godb, keytype = "GOID"), , drop = FALSE]
  mapping <- unique(mapping[, c(cfg$key_type, "GOALL"), drop = FALSE])
  if (!nrow(mapping)) return(NULL)
  pathways <- lapply(split(mapping[[cfg$key_type]], mapping$GOALL), unique)
  descriptions <- AnnotationDbi::select(godb, keys = names(pathways), keytype = "GOID", columns = c("TERM", "ONTOLOGY"))
  set.seed(cfg$seed)
  result <- as.data.frame(fgsea::fgseaMultilevel(pathways = pathways, stats = ranks,
      minSize = cfg$min_gs_size, maxSize = cfg$max_gs_size, eps = cfg$eps,
      sampleSize = 101, nPermSimple = 1000, gseaParam = 1, scoreType = "std",
      BPPARAM = BiocParallel::SerialParam(RNGseed = cfg$seed)))
  if (!nrow(result)) return(NULL)
  qvalues <- rep(NA_real_, nrow(result))
  finite <- is.finite(result$pval)
  if (sum(finite) > 1L) {
    qvalues[finite] <- tryCatch(qvalue::qvalue(result$pval[finite])$qvalues,
                              error = function(e) rep(NA_real_, sum(finite)))
  }
  tab <- data.frame(ID = result$pathway,
    Description = descriptions$TERM[match(result$pathway, descriptions$GOID)],
    ONTOLOGY = descriptions$ONTOLOGY[match(result$pathway, descriptions$GOID)],
    setSize = result$size, enrichmentScore = result$ES, NES = result$NES,
    pvalue = result$pval, p.adjust = p.adjust(result$pval, method = "BH"), qvalue = qvalues,
    core_enrichment = vapply(result$leadingEdge, paste, character(1), collapse = "/"),
    stringsAsFactors = FALSE)
  tab <- tab[order(tab$p.adjust, -abs(tab$NES), na.last = TRUE), , drop = FALSE]
  rownames(tab) <- tab$ID
  # 标准结果容器只用于保存与enrichplot；p值/NES来自上面的明确fgsea调用。
  object <- methods::new("gseaResult", result = tab, geneSets = pathways, geneList = ranks,
    params = list(pvalueCutoff = 1, exponent = 1, minGSSize = cfg$min_gs_size,
                  maxGSSize = cfg$max_gs_size, eps = cfg$eps, backend = "fgseaMultilevel"), readable = FALSE)
  if ("setType" %in% methods::slotNames(object)) object@setType <- cfg$ontology
  if ("keytype" %in% methods::slotNames(object)) object@keytype <- cfg$key_type
  object
}

# 每个比较单独读取完整 DE 表；注释永不回写/扩增基因级 DE 主表。
run_enrichment <- function(contrasts, runtime, de_dir, output) {
  need(c("clusterProfiler", "AnnotationDbi", "ggplot2", "enrichplot", "BiocParallel"))
  cfg <- runtime$config$enrichment
  need(cfg$orgdb)
  orgdb <- getExportedValue(cfg$orgdb, cfg$orgdb)
  available <- AnnotationDbi::keys(orgdb, keytype = cfg$key_type)
  if (!dir.create(output, recursive = TRUE, showWarnings = FALSE)) stopf("Enrichment output exists or is not writable")
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
          pvalue = numeric(), p.adjust = numeric()) else as.data.frame(object@result)
      if (anyNA(table$ID) || any(!nzchar(table$ID))) stopf("Invalid GO identifiers returned; cannot export as successful enrichment")
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
      gse <- go_gsea_fgsea(ranks, orgdb, cfg)
      write_json(list(backend = "fgsea::fgseaMultilevel", version = as.character(utils::packageVersion("fgsea")),
          seed = cfg$seed, eps = cfg$eps, min_gs_size = cfg$min_gs_size, max_gs_size = cfg$max_gs_size,
          score_type = "std", exponent = 1, nPermSimple = 1000, sampleSize = 101,
          mapping = "OrgDb GOALL; set sizes intersected with ranked genes; same fgsea default semantics"), file.path(folder, "go_gsea_backend.json"))
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
