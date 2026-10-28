# 本地 OrgDb + 人工效应值的接口 smoke test；不用于解释任何真实生物学结果。
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[1] else ".")
source(file.path(repo, "scripts/R/common.R"))
source(file.path(repo, "scripts/R/enrichment.R"))
need(c("org.Mm.eg.db", "clusterProfiler", "enrichplot", "AnnotationDbi", "BiocParallel"))
db <- getExportedValue("org.Mm.eg.db", "org.Mm.eg.db")
set.seed(19)
ids <- sample(AnnotationDbi::keys(db, keytype = "ENSEMBL"), 1000)
mapping <- AnnotationDbi::select(db, keys = ids, keytype = "ENSEMBL", columns = c("GOALL", "ONTOLOGYALL"))
mapping <- unique(mapping[mapping$ONTOLOGYALL == "BP" & !is.na(mapping$GOALL), c("ENSEMBL", "GOALL")])
sizes <- table(mapping$GOALL)
target <- names(sizes[sizes >= 15 & sizes <= 30])[1]
stopifnot(!is.na(target))
genes <- unique(mapping$ENSEMBL[mapping$GOALL == target])
stat <- rnorm(length(ids))
stat[ids %in% genes] <- 5 + runif(sum(ids %in% genes))
tab <- data.frame(gene_id = ids, log2FoldChange = stat, stat = stat,
                  pvalue = 0.5, padj = 0.5, regulated = "normal")
tab$padj[ids %in% genes] <- 0.001
tab$regulated[ids %in% genes] <- "up"
tmp <- tempfile("bulkrna_enrichment_")
dir.create(file.path(tmp, "gene_diff_expr", "synthetic"), recursive = TRUE)
write.csv(tab, file.path(tmp, "de/synthetic/all_genes.csv"), row.names = FALSE)
cfg <- list(analysis = list(gsea = TRUE, go_enrichment = TRUE), enrichment = list(
  orgdb = "org.Mm.eg.db", key_type = "ENSEMBL", ontology = "BP", fdr = 0.05,
  min_gs_size = 10L, max_gs_size = 100L, gsea_rank = "stat", seed = 19L, eps = 0.001, show_category = 5L))
run_enrichment(data.frame(contrast_id = "synthetic"), list(config = cfg), file.path(tmp, "gene_diff_expr"), file.path(tmp, "out"))
folder <- file.path(tmp, "out/synthetic")
stopifnot(file.exists(file.path(folder, "go_gsea.rds")), file.exists(file.path(folder, "go_ora_up.rds")))
stopifnot(file.exists(file.path(folder, "go_ora_up_dotplot.pdf")))
down <- read_json(file.path(folder, "go_ora_down_status.json"))
stopifnot(down$status == "no_significant_terms")
cat("PASS: local OrgDb + synthetic GO GSEA/ORA/export/plot/empty-direction smoke test\n")
