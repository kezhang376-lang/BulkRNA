# BulkRNA V1

当前版本：**1.0.0**，Git发布标签：**v1.0.0**。用户已确认当前项目验证成功；本次发布保存已验证代码和配置，不重跑服务器分析。

Windows维护代码、配置和记录，通过kubectl在用户准备的Shell Pod和R Pod中运行：

```text
配置/样本/比较表 → 校验、冻结包、上传、SHA256核验
  → Shell：fastp → STAR → BAM检查/索引 → featureCounts → MultiQC
  → 验收counts后投递R：样本QC → DESeq2 → GO ORA/GSEA → report.html
```

阶段内部自动执行，Shell与R仍需衔接投递；无自动跨Pod调度、指纹断点恢复、模式B/C完整调度、KEGG、LRT或WGCNA。Pod必须使用指定非root账号。

## 当前项目

- 项目：projects/20261018_xiehe_zhou，两组各3样本，10GY5FFRT相对Control。
- 实际包：projects/20261018_xiehe_zhou/releases/v1_test6_20261027_retry01及同名tar.gz。
- Shell已通过6样本验收，R已投递；验证成功状态由用户确认，本次版本管理不替代最终科研结果审阅。
- 项目计划在analysis_plan.md，运行、错误及验收证据在logs/。
- 服务器包和结果保持原样；项目qc目录中已下载结果保留但不提交Git。

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

main为工作基线，v1.0.0固定本次发布；baseline-before-v1-cleanup保存清理前旧构建。后续先创建开发分支，测试后发布新标签，为计算生成新run_id。

```powershell
git status --short
git log --oneline --decorate -5
git switch -c feature/your-analysis
```

不要直接修改冻结包、移动发布标签或覆盖历史结果。GitHub仓库：[kezhang376-lang/BulkRNA](https://github.com/kezhang376-lang/BulkRNA)，发布分支main，V1标签v1.0.0。原始测序数据和本地分析结果不上传。

## 操作与填写参考

- [Git管理、清理和后续开发方法](docs/08_Git版本管理与清理说明.md)
- [版本变更记录](CHANGELOG.md)
- [完整配置示例](config/review.example.yaml)及[当前字段规范](schemas/config.schema.json)
- [项目运行包索引](projects/20261018_xiehe_zhou/releases/README.md)
- [V1方法及Pod兼容性记录](docs/07_V1运行包交付与Pod验收.md)
- [配置逐字段解读历史初稿](docs/legacy_config_guide_20261027.md)：保留原先解读，但含旧占位值和未来接口建议，不能作为当前实现状态。

发布清单见docs/releases/v1.0.0.json。工具版本见运行结果shell/versions.json和analysis/sessionInfo文件；源码版本不等于环境或参考数据库已锁定。
