# 版本变更记录

## 2.0.0 — 2026-10-28（正式发布）

- 新运行结果直接进入output_dir/run_id，移除中间runs层。
- Shell全阶段目录改为bam_count_data，R全阶段目录改为gene_expr_data，内部de改为gene_diff_expr。
- 同步计数输入、阶段状态检查、后台入口防覆盖检查、报告、兼容性探针和测试。
- 新运行包、压缩包及服务器代码目录均与run_id同名；run_id为v<流程版本>_<YYYYMMDD>_run<至少两位正序号>，版本来自VERSION，日期和序号校验。
- runtime增加pipeline_version/output_layout_version；新源码拒绝旧V1运行配置，防止混用目录。配置schema_version保持1.0-review。
- 新生成包提供README_CN.md，不再复制旧V1项目操作说明。
- 项目专用R依赖队列已在真实Pod验证：Shell成功并验收后启动R，Shell失败/48小时超时则停止；不是通用跨Pod调度器。
- 完成6样本全流程验收，核心计数及差异表与V1一致；GSEA警告保留并记录。
- 修复本地C locale下后续生成README_CN.md的中文编码，新增回归检查；已运行冻结包不改写，另附可读说明。
- 这是输出路径接口的不兼容变化，因此提升到2.0.0；不迁移旧V1包/结果，不改变统计参数，不自动投递任务。Git标签v1.0.0保留原样。

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
