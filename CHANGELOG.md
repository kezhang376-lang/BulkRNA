# 版本变更记录

## 1.0.0 — 2026-10-27

- 首个Git基线版本；用户确认当前项目流程验证成功。
- GitHub发布目标：kezhang376-lang/BulkRNA，main分支及v1.0.0标签；使用用户指定身份提交。
- 标准PE流程：fastp → STAR → samtools BAM检查/索引 → featureCounts → MultiQC。
- R流程：样本QC、DESeq2 pairwise Wald、GO ORA/GSEA及HTML结果索引。
- 配置与元数据校验、非root账号检查、冻结运行包SHA256校验、后台入口、启动锁、PID/日志/状态记录。
- 固定旧fastp配置及0.21.0；GO GSEA直接使用fgseaMultilevel以兼容当前R Pod。
- 项目实际运行包：v1_test6_20261027_retry01。保留此前50GiB容器失败记录，之后更换300GiB Shell Pod。
- Git保存源码、配置、规范、测试、小型运行证据及有效冻结包；项目qc目录的结果留在磁盘且不纳入Git。
- 清理废弃prepared审查包、r1/r2/r3构建及旧Pod配置.bak；清理前全部保存在恢复标签baseline-before-v1-cleanup。

限制：无Shell→R自动跨Pod调度、指纹断点恢复、模式B/C完整调度、KEGG、LRT或WGCNA。保存源码版本不等于锁定Pod镜像、软件环境或参考数据库。

后续版本先创建开发分支，补齐配置规范、测试、文档和变更记录，完成验证后提交并创建新标签。不要移动v1.0.0标签或修改已冻结运行包。
