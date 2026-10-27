# R阶段正式启动记录

- 用户授权：核实Shell完成后启动R阶段，稳定运行后结束监控。
- run_id：v1_test6_20261027_retry01；沿用原冻结包与参数，不重跑Shell。
- Shell于2026-10-27北京时间19:43:52成功。启动R前逐项验收6个BAM的quickcheck/索引、计数列与样本对应、57010基因非负整数计数、每列计数和与featureCounts Assigned一致及MultiQC报告；冻结包SHA256一致。详情见shell_final_audit.json。
- 原始计数矩阵SHA256：0e163c0e49aca82261962eedf8cd461173b3841957fe576d3132416505a28654。
- R Pod：zkr1-med-5d8b8c5b48-tggbt；container：zkr250903-container；CPU限额64、内存限额300GiB；无重启。
- 账号zhangke，UID1482；/usr/bin/Rscript。输入、包加载、过滤及设计检查通过，项目config.yaml与冻结包原始配置指纹一致。
- 启动时间：2026-10-27北京时间20:14:05；后台PID492。
- 范围：描述性样本QC、现有过滤、DESeq2 pairwise Wald、GO ORA/GSEA、HTML报告；禁用的KEGG和custom不执行。
- 模型与阈值：~group；parametric拟合；BH FDR0.05，abs(log2FC)>1；10GY5FFRT相对Control。无参数/样本/环境变更。
- 结果目录：/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_retry01/analysis。
- 后台日志：同run根目录launcher/r.launcher.log；分析日志：analysis/analysis.log；状态：analysis/status.json。
- 北京时间20:14:25启动后检查：running，PID492为真实R进程，UID1482，RSS约1.44GiB；已生成QC图、dds.rds、差异表及MA/火山图，开始GO富集。尚未做最终产物验收。
- 日志有Control不是默认参考水平的建议；代码使用显式contrast=c(group,treatment,control)，已固定所需比较方向，未自动调整因子水平。另有注释一对多映射提示，需结合映射诊断解释，不当作运行失败。

已按用户要求结束持续监控；不安排自动后续检查。启动成功及阶段性文件存在不代表整个R阶段成功或科研结论成立。最终完成状态、GO结果及报告待用户下次要求时检查。
