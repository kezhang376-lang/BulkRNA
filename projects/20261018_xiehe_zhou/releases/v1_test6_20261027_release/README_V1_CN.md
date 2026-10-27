# 两组6样本 BulkRNA V1 运行说明

本文件配合本项目 releases 下的完整运行包使用。运行包冻结通用代码、项目配置、样本表、比较表和运行入口，拷贝整个目录即可在指定Pod运行，无需访问Windows代码仓库。

当前交付版本为 `v1_test6_20261027_release`；最终验收状态以项目兼容性核验报告为准。完整6样本分析尚未启动，兼容性探针的结果不能作为生物学结论。

## 1. 代码位置与输出位置

- Windows包目录：`releases/v1_test6_20261027_release/`。
- Windows可拷贝压缩包：`releases/v1_test6_20261027_release.tar.gz`，旁边有SHA256校验文件。
- 服务器包目录：`/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release/`。
- 服务器真实结果根目录：`/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_release/`。
- 独立兼容性测试目录：`/home/zhangke/RNA-seq/20261027_xiehe_zhou/validation/v1_test6_20261027_release/`。

输出位置由runtime.json固定，不随代码目录的位置变化。不要只拷贝某一个R或Shell文件；不要手工编辑冻结包或复用旧run_id。重新配置时应在Windows生成新包和新run_id。

## 2. Pod与身份

| 阶段 | Pod | 账号 |
|---|---|---|
| Shell | zk1-med-6ff4f46898-rlbtd | zhangke（UID1482） |
| R | zkr1-med-5d8b8c5b48-tggbt | zhangke（UID1482） |

context=`zhangke@med.thu`，namespace=`renkelab-zhangke`。两Pod共享/home/zhangke，因此第二阶段可以读取第一阶段产物。

以下命令假定已经在对应Pod中以zhangke身份运行；如果进入Pod后是root，先用 `runuser -u zhangke -- bash <入口路径> <参数>` 调用。不要以root直接执行分析。包本身只检查身份，不自动切换账号或修改Pod配置。

Shell工具由配置的`/miniconda3/bin`定位；fastp例外，严格使用旧配置指定的`/home/zhangke/soft/fastp_dir/fastp`且核验0.21.0。R阶段固定`/usr/bin/Rscript`，两Pod都需要python3用于入口与包校验。

## 3. 启动前检查（不会启动6样本分析）

Shell Pod中：

```bash
cd /home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release
bash run_shell.sh --check-only
```

R Pod中：

```bash
cd /home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release
bash run_R.sh --environment-only
```

第二条只核验账号、样本/比较和R包加载，不要求Shell已经生成counts。Shell完成后，才运行R的完整输入检查 `bash run_R.sh --check-only`。

所有入口都先核对MANIFEST.sha256.json。更改代码、配置或元数据后直接运行会被拒绝；不要删除清单来绕过校验。

## 4. 已获本次启动授权后的真实分析

长任务建议使用分离会话入口。**这些命令不是本次准备和兼容性核验的一部分，不能因检查通过而自动调用。**

Shell Pod：

```bash
cd /home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release
bash start_shell.sh --execute
```

返回`launched_not_completed`和PID仅表示已启动。先检查结果根目录 `shell/status.json` 为`succeeded`并验收counts，再进入R Pod：

```bash
cd /home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release
bash run_R.sh --check-only
bash start_R.sh --execute
```

后台入口先执行check-only，再建立本阶段独占启动锁，记录PID、时间和日志。关闭kubectl会话不会主动结束已分离的计算进程；Pod重启/驱逐仍会中断任务。锁不是断点恢复功能，失败后不要直接删锁重启。

也可在稳定前台会话中运行 `bash run_shell.sh --execute` 或 `bash run_R.sh --execute`；前台/后台二选一，禁止对同一阶段重复启动。R入口会强制检查Shell已成功，不能边写counts边做统计。

## 5. 状态与主要结果

| 路径（相对真实结果根目录） | 内容 |
|---|---|
| launcher/shell.launch.json、r.launch.json | 后台启动信息，不是成功标记 |
| launcher/*.launcher.log | 总入口日志 |
| shell/status.json、analysis/status.json | 运行/成功/失败状态 |
| shell/fastp.config.snapshot、fastp.resolved.json、versions.json | 旧fastp原配置、解析参数、程序路径与实际版本 |
| shell/clean、shell/bam | clean FASTQ和排序BAM等大文件 |
| shell/counts/raw_counts.tsv | 统一gene_id×sample_id整数矩阵 |
| shell/qc | fastp/STAR/featureCounts统计、MultiQC报告 |
| shell/logs | 工具原始日志 |
| analysis/qc | 表达分布、PCA、相关性、聚类和表格 |
| analysis/de | dds.rds、标准化counts、完整比较表、MA/火山图及汇总 |
| analysis/enrichment | GO ORA/GSEA、映射诊断、通路表、RDS和图 |
| analysis/report.html | 可直接用浏览器打开的运行结果索引与汇总 |
| analysis/analysis.log、sessionInfo*.txt | R日志和包版本记录 |

只有两个阶段均成功、输出验收通过，才可称本次数据流程已完成；不能把程序退出0、图存在或显著通路数量当作科研结论正确的证明。

## 6. V1方法边界

本轮：两组各3样本，10GY5FFRT相对Control；旧fastp配置+0.21.0、STAR、PE fragment featureCounts、描述性样本QC、DESeq2 pairwise Wald、GO ORA/GSEA、MultiQC。

统计参数保持用户配置：~group、FDR0.05、abs(log2FC)>1、legacy75%非零过滤（6样本至少4个非零）、GO集大小3–800、log2FC排序。没有自动做VST/TMM、样本剔除、批次校正或方法降级。

KEGG、21样本七组的LRT、WGCNA及模式B/C自动调度尚不在本轮V1中。不能靠更改描述或开关认为已实现。包支持独立新运行和基本后台启动保护，不支持按指纹断点恢复；已有产物不覆盖。

GSEA后端兼容说明：为避免新版clusterProfiler忽略后端参数，V1直接调用fgsea::fgseaMultilevel，保留GOALL映射、排序、集合范围、BH、seed和eps；结果仍使用标准gseaResult容器供enrichplot绘图。
