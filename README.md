# BulkRNA

当前正式版本：**2.0.0**，Git标签：**v2.0.0**，发布日期：2026-10-28。已完成6样本Shell与R真实Pod运行及主要产物验收；v1.0.0、旧冻结包和服务器结果保留原样。

新布局：`results/<run_id>/bam_count_data/`与`results/<run_id>/gene_expr_data/gene_diff_expr/`，不含runs层。运行包与结果目录同名，例如`v2.0.0_20261027_run01`。说明及完整修改文件清单见[新目录规则](docs/09_新结果目录规则与修改清单.md)。

Windows维护代码、配置和记录，通过kubectl在用户准备的Shell Pod和R Pod中运行：

```text
配置/样本/比较表 → 校验、冻结包、上传、SHA256核验
  → Shell：fastp → STAR → BAM检查/索引 → featureCounts → MultiQC
  → 验收counts后投递R：样本QC → DESeq2 → GO ORA/GSEA → report.html
```

阶段内部自动执行。本次项目另外提供R Pod后台依赖等待脚本：Shell成功且依赖验收通过后启动R，失败或等待48小时超时则停止。该脚本是项目专属附加项，通用准备器不会为每个新项目自动生成它；尚无通用跨Pod调度器、指纹断点恢复、模式B/C完整调度、KEGG、LRT或WGCNA。Pod必须使用指定非root账号。

## 当前项目

- V2验证项目：projects/20261027_xiehe_zhou，两组各3样本，10GY5FFRT相对Control。
- 冻结包：projects/20261027_xiehe_zhou/releases/v2.0.0_20261028_run01及同名tar.gz。
- Shell于2026-10-28北京时间02:02:18完成，R于02:06:30完成；6个BAM、57010×6计数、模型及报告41个链接核查通过。
- 核心计数矩阵、完整/显著差异表与V1 SHA256一致；GSEA有8条NA通路、并列排序及P值下限警告，保留原参数并记录，不以流程成功代替科研解释。
- [完成验收报告](logs/v2.0.0_20261028_run01/completion_report.md)、[V2运行说明](projects/20261027_xiehe_zhou/运行说明_V2.md)。
- 冻结包内README_CN.md是当时生成的编码异常快照，不改写；请用上述运行说明。发布源码已修复后续中文说明生成并增加回归检查。
- 历史V1项目projects/20261018_xiehe_zhou及实际运行包继续保留；下载的qc结果不提交Git。

## 目录职责

| 位置 | 用途 |
|---|---|
| AGENTS.md | 协作、科研和正式启动规则 |
| scripts/shell、scripts/R | 标准分析源码 |
| workflow/orchestrator | 准备、打包、上传及调度工具 |
| workflow/modules/validation、tests | 小数据和接口检查 |
| config、schemas | 默认值、完整示例和实际字段规范 |
| projects/<项目>/ | 配置、样本、比较、计划、custom专属脚本 |
| projects/<项目>/releases/ | 保持原样的实际运行包及指纹 |
| logs、docs | 运行证据、历史审查和操作说明 |
| VERSION、CHANGELOG.md | 流程版本和变更记录 |
| step1_shell.sh、step2_Rscript.R | 原始方法参考 |

skills仅有目录占位，目前没有可调用的SKILL.md。

## 版本维护

main为工作基线，v2.0.0固定本次发布，v1.0.0保留为历史基线；baseline-before-v1-cleanup保存清理前旧构建。后续先创建开发分支，测试后发布新标签，为计算生成新run_id。

```powershell
git status --short
git log --oneline --decorate -5
git switch -c feature/your-analysis
```

不要直接修改冻结包、移动发布标签或覆盖历史结果。GitHub仓库：[kezhang376-lang/BulkRNA](https://github.com/kezhang376-lang/BulkRNA)，发布分支main，当前标签v2.0.0，历史标签v1.0.0。原始测序数据和本地分析结果不上传。

## 操作与填写参考

- [Git管理、清理和后续开发方法](docs/08_Git版本管理与清理说明.md)
- [版本变更记录](CHANGELOG.md)
- [完整配置示例](config/review.example.yaml)及[当前字段规范](schemas/config.schema.json)
- [V2发布与验收说明](docs/10_V2发布说明与验收记录.md)
- [当前项目运行包索引](projects/20261027_xiehe_zhou/releases/README.md)
- [V1方法及Pod兼容性记录](docs/07_V1运行包交付与Pod验收.md)
- [配置逐字段解读历史初稿](docs/legacy_config_guide_20261027.md)：保留原先解读，但含旧占位值和未来接口建议，不能作为当前实现状态。

当前发布清单见docs/releases/v2.0.0.json；V1历史清单见docs/releases/v1.0.0.json。新布局的工具版本见bam_count_data/versions.json，R环境见gene_expr_data/sessionInfo文件；源码版本不等于环境或参考数据库已锁定。
