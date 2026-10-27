write_summary_report <- function(runtime, samples, contrasts, out) {
  esc <- function(x) {
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
  }
  summary_file <- file.path(out, "de", "contrast_summary.csv")
  summary <- if (file.exists(summary_file)) read.csv(summary_file) else data.frame()
  html_table <- function(tab) {
    if (!nrow(tab)) return("<p>No table generated for this module.</p>")
    paste0("<table><thead><tr>", paste0("<th>", esc(names(tab)), "</th>", collapse = ""),
      "</tr></thead><tbody>", paste(apply(tab, 1, function(row) paste0("<tr>",
        paste0("<td>", esc(row), "</td>", collapse = ""), "</tr>")), collapse = ""), "</tbody></table>")
  }
  files <- list.files(out, recursive = TRUE)
  files <- files[grepl("[.](pdf|csv|tsv|txt|json)$", files) & !grepl("^runtime[.]json$", files)]
  links <- paste0('<li><a href="', files, '">', esc(files), '</a></li>')
  html <- c('<!doctype html><html lang="zh-CN"><meta charset="utf-8">',
    '<title>BulkRNA V1 analysis report</title><style>body{font:16px sans-serif;max-width:1100px;margin:3em auto;line-height:1.6}table{border-collapse:collapse}th,td{border:1px solid #ccc;padding:.5em}code{background:#eee}</style>',
    '<h1>BulkRNA V1 analysis report</h1>', paste0('<p>Project: ', esc(runtime$config$project$id), '<br>Run: ', esc(runtime$run_id), '</p>'),
    '<p>This report summarizes configured computations. Statistical significance does not establish biological validity; review QC and model assumptions.</p>',
    '<h2>Samples</h2>', html_table(samples[, c("sample_id", "group"), drop = FALSE]),
    '<h2>Comparisons</h2>', html_table(contrasts), '<h2>Differential expression summary</h2>', html_table(summary),
    '<h2>Methods</h2>', paste0('<pre>', esc(jsonlite::toJSON(list(filtering = runtime$config$filtering,
      deseq2 = runtime$config$deseq2, enrichment = runtime$config$enrichment), auto_unbox = TRUE, pretty = TRUE)), '</pre>'),
    '<p>Full counts, BAM, fastp, STAR and MultiQC outputs are in the sibling shell directory.</p>',
    '<h2>Tables, figures and logs</h2><ul>', links, '</ul></html>')
  write_utf8_lf(html, file.path(out, "report.html"))
}
