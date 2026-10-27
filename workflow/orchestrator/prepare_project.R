#!/usr/bin/env Rscript
# 仅本地准备：无 kubectl、无上传、无任务启动。输出可以是 blocked 运行包供审查。
prepare_entry <- function() sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])

merge_config <- function(base, project) {
  for (key in names(project)) {
    if (is.list(base[[key]]) && is.list(project[[key]]) &&
        !is.null(names(base[[key]])) && !is.null(names(project[[key]]))) {
      base[key] <- list(merge_config(base[[key]], project[[key]]))
    } else base[key] <- list(project[[key]]) # 保留显式 null，不删除键。
  }
  base
}

# 实现本仓库 schema 用到的关键字；不是完整 JSON Schema 引擎。
validate_schema <- function(value, schema, prefix = "config") {
  errors <- character()
  add <- function(msg) errors <<- c(errors, paste0(prefix, ": ", msg))
  types <- unlist(schema$type)
  matches <- function(type) switch(type, null = is.null(value),
    object = is.list(value) && (length(value) == 0 || !is.null(names(value))),
    array = is.list(value) && is.null(names(value)),
    string = is.character(value) && length(value) == 1L && !is.na(value),
    boolean = is.logical(value) && length(value) == 1L && !is.na(value),
    number = is.numeric(value) && length(value) == 1L && is.finite(value),
    integer = is.numeric(value) && length(value) == 1L && is.finite(value) && value == round(value), FALSE)
  if (!any(vapply(types, matches, logical(1)))) {
    add(paste("expected", paste(types, collapse = "/")))
    return(errors)
  }
  if (!is.null(schema$enum) && !any(vapply(schema$enum, function(x) isTRUE(all.equal(value, x, check.attributes = FALSE)), logical(1)))) add("not an allowed value")
  if (is.null(value)) return(errors)
  if ("object" %in% types && is.list(value)) {
    missing <- setdiff(unlist(schema$required), names(value))
    for (key in missing) add(paste("missing", key))
    if (identical(schema$additionalProperties, FALSE)) {
      for (key in setdiff(names(value), names(schema$properties))) add(paste("unknown key", key))
    }
    for (key in intersect(names(value), names(schema$properties))) errors <- c(errors, validate_schema(value[[key]], schema$properties[[key]], paste(prefix, key, sep = ".")))
  }
  if ("array" %in% types && is.list(value)) for (i in seq_along(value)) errors <- c(errors, validate_schema(value[[i]], schema$items, sprintf("%s[%d]", prefix, i)))
  if (is.character(value)) {
    if (!nzchar(value)) add("empty string")
    if (!is.null(schema$pattern) && !grepl(schema$pattern, value, perl = TRUE)) add("invalid format")
    if (grepl("[\r\n]", value)) add("embedded newline not allowed")
  }
  if (is.numeric(value)) {
    if (!is.null(schema$minimum) && value < schema$minimum) add("below minimum")
    if (!is.null(schema$maximum) && value > schema$maximum) add("above maximum")
    if (!is.null(schema$exclusiveMinimum) && value <= schema$exclusiveMinimum) add("must exceed minimum")
    if (!is.null(schema$exclusiveMaximum) && value >= schema$exclusiveMaximum) add("must be below maximum")
  }
  errors
}

prepare_project <- function(config_file, run_id, output, repo) {
  source(file.path(repo, "scripts", "R", "common.R"), local = TRUE)
  need(c("yaml", "jsonlite"))
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", run_id) || run_id %in% c(".", "..")) stopf("Invalid run_id")
  config_file <- normalizePath(config_file, mustWork = TRUE)
  project_dir <- dirname(config_file)
  load_yaml <- function(path) {
    # readLines(encoding=)标记 UTF-8，避免 Windows 的 C locale 转码损坏中文。
    value <- yaml::yaml.load(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"),
                              eval.expr = FALSE, handlers = list(seq = function(x) as.list(x)))
    if (!is.list(value) || is.null(names(value))) stopf("YAML root must be a mapping: %s", path)
    value
  }
  cfg <- merge_config(load_yaml(file.path(repo, "config", "defaults.yaml")), load_yaml(config_file))
  schema <- read_json(file.path(repo, "schemas", "config.schema.json"))
  blockers <- validate_schema(cfg, schema)
  malformed <- names(schema$properties)[vapply(names(schema$properties), function(key) {
    "object" %in% unlist(schema$properties[[key]]$type) && key %in% names(cfg) && !is.list(cfg[[key]])
  }, logical(1))]
  if (length(malformed)) stopf("Invalid configuration sections: %s; %s", paste(malformed, collapse = ", "), paste(blockers, collapse = "; "))
  notes <- c("Prepared locally only. No Kubernetes check, upload, or analysis executed.",
             "Remote storage, capacity, reference identity and scientific design still require review.",
             "Formal execution requires separate user authorization; launchers default to check-only.")
  add <- function(x) blockers <<- c(blockers, x)
  account <- cfg$kubernetes$account
  if (!is.character(account) || length(account) != 1L || !grepl("^(?!root$)[a-z_][a-z0-9_-]*$", account, perl = TRUE)) {
    add("kubernetes.account must specify a non-root Linux account")
  } else notes <- c(notes, paste0("Pod Linux account must be ", account, "; switch identity before launching. Workers reject root/wrong UID; no automatic account switching is implemented."))
  # 当前版本只实现标准全新运行，明确拒绝假装支持恢复/模式B/C。
  if (!identical(cfg$execution$mode, "standard")) add("v1 supports standard mode only; custom/reuse orchestration not implemented")
  if (!identical(cfg$execution$resume, FALSE)) add("v1 has no fingerprint-verified resume; set resume=false only for an agreed fresh run")
  if (!identical(cfg$execution$overwrite, FALSE)) add("v1 requires overwrite=false")
  if (isTRUE(cfg$analysis$kegg_enrichment)) add("KEGG module not implemented in v1; do not silently disable an intended analysis")
  if (isTRUE(cfg$analysis$custom_analysis)) add("Project-specific analysis requires its own reviewed plan/script; v1 standard launcher cannot execute it")
  if ((isTRUE(cfg$analysis$go_enrichment) || isTRUE(cfg$analysis$gsea)) && !isTRUE(cfg$analysis$differential_expression)) add("GO/GSEA currently require DE outputs from the same run")
  if (isTRUE(cfg$analysis$go_enrichment) || isTRUE(cfg$analysis$gsea)) {
    if (is.null(cfg$enrichment)) add("Missing enrichment settings")
    expected <- c(mouse = "org.Mm.eg.db", human = "org.Hs.eg.db")
    if (!is.null(cfg$enrichment$orgdb) && !identical(unname(expected[cfg$species$name]), cfg$enrichment$orgdb)) add("OrgDb and species disagree")
    if (!is.null(cfg$enrichment$min_gs_size) && !is.null(cfg$enrichment$max_gs_size) && cfg$enrichment$min_gs_size > cfg$enrichment$max_gs_size) add("min_gs_size exceeds max_gs_size")
  }
  for (key in c("shell_pod", "r_pod", "context")) {
    value <- cfg$kubernetes[[key]]
    if (is.null(value) || !is.character(value) || grepl("pod-name|REPLACE|TODO|^$", value)) add(paste("Missing actual kubernetes", key))
  }
  for (key in c("input_dir", "output_dir", "counts_file")) {
    value <- cfg$paths[[key]]
    if (!is.null(value) && is.character(value) && grepl("project001|REPLACE|TODO", value)) add(paste("Placeholder paths", key))
  }
  if (is.null(cfg$paths$output_dir) || !is.character(cfg$paths$output_dir) || !startsWith(cfg$paths$output_dir, "/")) add("output_dir must be an absolute Linux path")
  if (is.character(cfg$paths$input_dir) && is.character(cfg$paths$output_dir)) {
    input_root <- sub("/+$", "", cfg$paths$input_dir)
    output_root <- sub("/+$", "", cfg$paths$output_dir)
    if (identical(input_root, output_root) || startsWith(output_root, paste0(input_root, "/"))) add("output_dir must not be inside the raw input directory")
  }
  # 安全解析本地元数据；当前文件缺 metadata 时仍可读取用于审查，schema 保持阻断。
  local_path <- function(value, fallback) {
    if (is.null(value)) value <- fallback
    if (grepl("^(/|[A-Za-z]:[/\\\\])", value)) value else file.path(project_dir, value)
  }
  samples_path <- local_path(cfg$metadata$samples, "samples.csv")
  contrasts_path <- local_path(cfg$metadata$contrasts, "contrasts.csv")
  samples <- read_metadata(samples_path, cfg$metadata$delimiter)
  contrasts <- read_metadata(contrasts_path, cfg$metadata$delimiter)
  validate_metadata(samples, contrasts)
  if (nrow(samples) < 3L) add("v1 requires >=3 samples")
  if (any(table(samples$group) < 2L)) add("v1 requires >=2 biological samples per group; confirm independence separately")
  if (!identical(cfg$project$id, basename(project_dir))) notes <- c(notes, "project.id differs from project folder; verify intended project identity")
  if (is.character(cfg$deseq2$design) && grepl(schema$properties$deseq2$properties$design$pattern, cfg$deseq2$design, perl = TRUE)) {
    variables <- all.vars(as.formula(cfg$deseq2$design))
    if (!"group" %in% variables || !all(variables %in% names(samples))) add("Design needs group and existing metadata columns")
    else {
      if (any(vapply(samples[variables], function(x) any(!nzchar(x) | x %in% c("NA", "unknown")), logical(1)))) add("Unknown values in design columns")
      design_error <- tryCatch({
        design_data <- samples
        design_data[variables] <- lapply(design_data[variables], factor)
        mm <- model.matrix(as.formula(cfg$deseq2$design), design_data)
        if (qr(mm)$rank < ncol(mm) || nrow(mm) <= ncol(mm)) "Design has no estimable residual model" else NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(design_error)) add(design_error)
    }
  }
  if (identical(cfg$input$type, "fastq")) {
    if (!identical(cfg$input$paired_end, TRUE)) add("v1 FASTQ pipeline supports paired-end only")
    if (is.null(cfg$input$strandedness)) add("Library strandedness is unknown")
    if (!all(c("fastq_r1", "fastq_r2") %in% names(samples))) add("samples missing fastq_r1/fastq_r2; filenames must not be guessed")
    else {
      values <- c(samples$fastq_r1, samples$fastq_r2)
      if (any(!nzchar(values)) || anyDuplicated(values)) add("FASTQ paths empty or reused across mates/samples")
    }
    for (key in c("fasta", "gtf", "star_index")) if (is.null(cfg$references[[key]]) || !is.character(cfg$references[[key]]) || !startsWith(cfg$references[[key]], "/")) add(paste("Missing absolute references", key))
    if (!all(vapply(cfg$analysis[c("fastp", "star", "featurecounts")], isTRUE, logical(1)))) add("v1 FASTQ requires fastp+STAR+featurecounts together; partial BAM reuse not implemented")
    if (is.null(cfg$paths$input_dir) || !is.character(cfg$paths$input_dir) || !startsWith(cfg$paths$input_dir, "/")) add("Missing absolute input_dir")
  } else if (identical(cfg$input$type, "counts")) {
    if (any(vapply(cfg$analysis[c("fastp", "star", "featurecounts")], isTRUE, logical(1)))) add("counts input requires fastp/star/featurecounts=false")
    if (is.null(cfg$paths$counts_file) || !is.character(cfg$paths$counts_file) || !nzchar(cfg$paths$counts_file)) add("Missing paths.counts_file")
    else if (!startsWith(cfg$paths$counts_file, "/")) add("counts_file must be an absolute Linux path in deployable bundles")
    notes <- c(notes, "Counts input is a NEW statistical analysis, not provenance-verified mode C reuse.")
  }
  if (identical(cfg$filtering$method, "legacy_nonzero_fraction") && is.null(cfg$filtering$fraction)) add("Missing filtering.fraction")
  if (identical(cfg$filtering$method, "min_count_samples") && (is.null(cfg$filtering$min_count) || is.null(cfg$filtering$min_samples))) add("Missing filtering min_count/min_samples")
  if (!is.null(cfg$filtering$min_samples) && cfg$filtering$min_samples > nrow(samples)) add("min_samples exceeds sample count")
  # 限定 fastp 可扩展选项，禁止覆盖输入/输出/报告/线程，以及启用其他执行流程。
  if (is.character(cfg$fastp$extra_args) && length(cfg$fastp$extra_args) == 1L) {
    if (!startsWith(cfg$fastp$extra_args, "/")) add("fastp.extra_args config path must be an absolute Linux path")
    notes <- c(notes, "fastp.extra_args is a legacy parameter file; the worker reads its specified binary and options without shell evaluation. File/version validation occurs on the Pod.")
  } else if (!is.null(cfg$fastp$extra_args)) {
    allowed_flags <- c("--disable_adapter_trimming", "--detect_adapter_for_pe", "--disable_quality_filtering", "--disable_length_filtering")
    allowed_values <- c("--adapter_sequence", "--adapter_sequence_r2", "--qualified_quality_phred", "--unqualified_percent_limit", "--n_base_limit", "--length_required")
    extra <- unlist(cfg$fastp$extra_args); i <- 1L
    while (i <= length(extra)) {
      token <- extra[i]
      if (token %in% allowed_flags) i <- i + 1L
      else if (token %in% allowed_values && i < length(extra) && !startsWith(extra[i + 1L], "-")) i <- i + 2L
      else { add(paste("Unsupported fastp extra argument:", token)); break }
    }
  }
  blockers <- unique(blockers)
  if (dir.exists(output) || file.exists(output)) stopf("Bundle output already exists: %s", output)
  if (!dir.create(output, recursive = TRUE)) stopf("Cannot create bundle: %s", output)
  output <- normalizePath(output)
  dir.create(file.path(output, "code"))
  for (folder in c("R", "shell")) {
    destination <- file.path(output, "code", folder)
    dir.create(destination)
    sources <- list.files(file.path(repo, "scripts", folder), full.names = TRUE)
    sources <- sources[file.info(sources)$isdir == FALSE]
    if (!all(file.copy(sources, destination))) stopf("Code snapshot copy failed")
  }
  yaml::write_yaml(cfg, file.path(output, "config.resolved.yaml"))
  file.copy(config_file, file.path(output, "config.original.yaml"))
  file.copy(samples_path, file.path(output, "samples.original.txt"))
  file.copy(contrasts_path, file.path(output, "contrasts.original.txt"))
  for (pair in list(list(samples, "samples.tsv"), list(contrasts, "contrasts.tsv"))) write.table(pair[[1]], file.path(output, pair[[2]]), sep = "\t", row.names = FALSE, quote = FALSE, fileEncoding = "UTF-8")
  root <- if (is.character(cfg$paths$output_dir)) paste0(sub("/+$", "", cfg$paths$output_dir), "/runs/", run_id) else NULL
  runtime <- list(bundle_version = "1.0-review", run_id = run_id, run_root = root,
    prepared_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), config = cfg,
    blockers = as.list(blockers), notes = as.list(notes))
  write_json(runtime, file.path(output, "runtime.json"))
  # 入口默认 check-only，只有显式 --execute 才计算；不含 Pod 名或 shell 插值配置。
  write_utf8_lf(c("#!/usr/bin/env bash", "set -Eeuo pipefail",
      'bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"',
      'exec python3 "${bundle_dir}/code/shell/launch_stage.py" shell "${bundle_dir}/runtime.json" "${1:---check-only}"'), file.path(output, "run_shell.sh"))
  write_utf8_lf(c("#!/usr/bin/env bash", "set -Eeuo pipefail",
      'bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"',
      'exec python3 "${bundle_dir}/code/shell/launch_stage.py" r "${bundle_dir}/runtime.json" "${1:---environment-only}"'), file.path(output, "run_R.sh"))
  for (stage in c("shell", "r")) {
    name <- if (stage == "r") "start_R.sh" else "start_shell.sh"
    write_utf8_lf(c("#!/usr/bin/env bash", "set -Eeuo pipefail",
      '[[ $# -eq 1 && "$1" == "--execute" ]] || { echo "Explicit --execute required" >&2; exit 2; }',
      'bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"',
      sprintf('exec python3 -B "${bundle_dir}/code/shell/start_stage.py" %s "${bundle_dir}/runtime.json" --execute', stage)), file.path(output, name))
  }
  plan <- c("# Generated review plan", "", paste("Run:", run_id),
    paste("Status:", if (length(blockers)) "BLOCKED" else "LOCAL_CONFIG_VALID_NOT_AUTHORIZED"), "",
    "## Module intent", paste0("- ", names(cfg$analysis), ": ", unlist(cfg$analysis)), "",
    "## Blockers", if (length(blockers)) paste0("- ", blockers) else "- No local config blockers; remote preflight and scientific review remain.",
    "", "## Notes", paste0("- ", notes))
  writeLines(enc2utf8(plan), file.path(output, "review_plan.md"), useBytes = TRUE)
  if (file.exists(file.path(project_dir, "analysis_plan.md"))) file.copy(file.path(project_dir, "analysis_plan.md"), file.path(output, "analysis_plan.md"))
  if (file.exists(file.path(project_dir, "README_V1_CN.md"))) file.copy(file.path(project_dir, "README_V1_CN.md"), file.path(output, "README_V1_CN.md"))
  validation_source <- file.path(repo, "workflow", "modules", "validation")
  if (dir.exists(validation_source)) {
    dir.create(file.path(output, "validation"))
    validation_files <- list.files(validation_source, full.names = TRUE)
    if (!all(file.copy(validation_files, file.path(output, "validation")))) stopf("Validation code copy failed")
  }
  readme <- c("# BulkRNA V1 portable project bundle", "", paste("Project:", cfg$project$id), paste("Run:", run_id), paste("Results root:", root),
    "", "This folder is self-contained. Copy/extract it as a whole; do not edit its frozen files. No Windows R/Python or repository checkout is required on the Pods.",
    paste("Required Linux account:", cfg$kubernetes$account),
    "Python3 is required on both Pods. Root/wrong-account execution is rejected. Switch account before calling the entrypoints.",
    "", "## Stage 1: Shell Pod", "```bash", "cd /absolute/path/to/this/bundle", "bash run_shell.sh --check-only", "# Only after launch authorization:", "bash run_shell.sh --execute", "```",
    "The launcher uses configured environment.shell_path_prepend. fastp uses the legacy config's pinned executable, not the PATH version.",
    "", "## Stage 2: R Pod (same shared bundle and result paths)", "```bash", "cd /absolute/path/to/this/bundle", "bash run_R.sh --environment-only", "# After Shell succeeds and counts exist:", "bash run_R.sh --check-only", "# Only after launch authorization:", "bash run_R.sh --execute", "```",
    "", "Run stages sequentially on their designated Pods. The package does not create or modify Pods, switch identities, transfer large files, or restart partial runs.",
    "Existing stage output directories are rejected. If a stage fails, inspect logs/status; do not delete outputs and retry blindly. No fingerprint resume is implemented.",
    "For long, authorized runs, use bash start_shell.sh --execute on the Shell Pod, then bash start_R.sh --execute on the R Pod AFTER Shell succeeds. These launch detached processes and write per-stage locks/PID/logs under results_root/launcher; launch success does not mean completion. Do not call them before authorization.",
    "", "## Outputs", "shell/clean, shell/bam, shell/counts/raw_counts.tsv, shell/qc, shell/logs, shell/status.json", "analysis/qc, analysis/de, analysis/enrichment, analysis/report.html, analysis/analysis.log, analysis/status.json", "", "All outputs are under the results root above, not the bundle folder.",
    "", "## Validation", "validation/ contains separate small-data compatibility checks. They require a NEW validation directory and do not run the full six-sample analysis.",
    "", "## Scope", "PE fastp/STAR/featureCounts, sample QC, pairwise DESeq2 Wald, GO ORA/GSEA, optional MultiQC. KEGG, LRT, WGCNA, mode B/C orchestration and resume are not included.",
    "", "MANIFEST.sha256.json verifies package contents before launch; changing any frozen file requires generating a new package.")
  write_utf8_lf(readme, file.path(output, "README_RUN.md"))
  files <- list.files(output, recursive = TRUE, full.names = TRUE)
  fingerprint <- data.frame(file = substring(files, nchar(output) + 2L), md5 = unname(tools::md5sum(files)))
  write.csv(fingerprint, file.path(output, "bundle_checksums_md5.csv"), row.names = FALSE)
  # SHA256清单由后续本地打包器生成；准备目录在生成前不可直接启动。
  message(sprintf("Prepared %s; blockers=%d. No analysis executed.", output, length(blockers)))
  invisible(runtime)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Usage: Rscript prepare_project.R <config.yaml> <run_id> <new_local_bundle_dir>", call. = FALSE)
  repo <- normalizePath(file.path(dirname(prepare_entry()), "..", ".."), mustWork = TRUE)
  result <- prepare_project(args[1], args[2], args[3], repo)
  if (length(result$blockers)) quit(status = 2L)
}
