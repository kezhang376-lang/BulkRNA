# 2.0新目录全流程启动记录

- 用户于2026-10-28授权20261027_xiehe_zhou项目Shell和R两个阶段，启动检查正常后停止本地持续监控。
- 项目ID：xiehe_zhouyisheng_20261027；run_id：v2.0.0_20261028_run01。
- 代码：2.0.0开发版，来自feature/result-directory-layout工作区，尚未发布Git标签。本次运行包冻结当前代码、配置、6样本和比较表，新增项目专属R依赖队列，不改科研参数。
- 代码目录：/home/zhangke/RNA-seq/20261028_xiehe_zhou/workflow/v2.0.0_20261028_run01。
- 结果根目录：/home/zhangke/RNA-seq/20261028_xiehe_zhou/results/v2.0.0_20261028_run01；Shell为bam_count_data，R为gene_expr_data，差异目录为gene_diff_expr，无runs层。
- 包SHA256：60bf437d0c6802a8e5d88919742afb7dc8875bf90d8e235d4c403f5b95ceb8f1；35文件。两个Pod均校验通过。
- Shell Pod：zk2-med-6dc5cbcb5d-wd5lj，container=zk260818-container；R Pod：zkr1-med-5d8b8c5b48-tggbt，container=zkr250903-container。两者均300GiB内存/64CPU限额；账号zhangke/UID1482。
- 启动前：12个FASTQ存在非空可读、空间约19.8TB、目标无冲突；fastp旧配置指纹未变，Shell工具检查及R依赖检查通过；19项Python测试及Pod入口语法通过。此前R本地布局集成已通过。
- Shell启动：北京时间2026-10-28 00:16:55，后台PID4053。启动后真实状态running，fastp子进程PID4178，UID1482。
- R等待任务投递：北京时间2026-10-28 00:17:07，R Pod后台PID958。启动后状态waiting_for_shell，读取同一共享Shell状态；R统计尚未开始，gene_expr_data尚未创建。
- R队列行为：每30秒读Shell状态，最多48小时；Shell成功后复核冻结包、运行快照、counts样本列/整数/Assigned总计、6个BAM索引、fastp/STAR计数及MultiQC，记录r.dependency_audit.json，再由原R后台入口执行包/输入/模型检查并启动R。Shell失败、依赖失败或等待超时均停止且记录failed，不重试、不自动恢复。状态r_launched_not_completed不表示R成功。
- 启动证据：shell_startup_check.json、r_queue_startup_check.json、startup_checks.json。Pod重启/驱逐仍可能中断；脚本不承诺重启恢复。

服务器日志：launcher/shell.launcher.log、bam_count_data/logs；R队列为launcher/r.queue.log和r.queue.status.json；R真正启动后为launcher/r.launcher.log、gene_expr_data/analysis.log和status.json。

按用户要求已结束本地持续监控。整个结果待后续验收，不提前认定2.0发布验证通过，不自动提交或推送GitHub。旧V1包及结果均未修改。

2026-10-28完成核查：Shell于02:02:18、R于02:06:30成功完成（北京时间）；新布局、BAM/计数、模型及报告主要产物通过，核心计数及差异表与V1一致。GSEA警告和8条NA通路单独记录。完整验收见completion_report.md及三个completion/r_final_audit JSON。本次未重跑、改参数或发布Git版本。
