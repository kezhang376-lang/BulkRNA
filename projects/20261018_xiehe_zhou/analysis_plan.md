# 两组六样本流程测试计划

日期：2026-10-27。用户已明确本轮先使用2组、6个样本进行流程测试。本计划记录样本范围与现有配置，不表示已经启动计算或通过全部方法/环境验收。

## 1. 本轮样本与比较

| 组别 | sample_id | 样本数 |
|---|---|---|
| 10GY5FFRT | 10GY5FFRT-1、10GY5FFRT-2、10GY5FFRT-3 | 3 |
| Control | control-1、control-2、control-3 | 3 |

唯一比较：`10GY5FFRT_vs_Control`，treatment=`10GY5FFRT`，control=`Control`；正log2FC表示10GY5FFRT相对Control上调。样本重复的生物学独立性、批次和配对信息不能仅由文件名证明。

samples.csv与contrasts.csv已通过UTF-8/CSV列数、非空、唯一性及比较组对应检查。当前FASTQ列指向上次Pod只读检查中存在的12个gzip文件。正式启动前需再次确认输入没有变动。

本轮使用这6个样本现有FASTQ；没有配置下采样，不自动截取reads。流程测试仍会涉及真实数据计算，本次只记录计划与生成本地准备包。

## 2. 当前配置记录

- 小鼠GRCm39、Ensembl109 GTF、现有STAR index；路径存在性和参考头部已检查，完整内容一致性/STAR实际加载兼容性未验证。
- 两个Pod使用已核实context `zhangke@med.thu`、namespace `renkelab-zhangke`；数据操作账号为zhangke（UID1482）。默认root必须先切换，不能以root执行分析。
- fastp读取Illumina_fastp.config，使用其指定的 `/home/zhangke/soft/fastp_dir/fastp`，版本固定0.21.0；旧过滤参数原样保留，线程数12。
- STAR、featureCounts、samtools、MultiQC使用经验证的登录环境；R阶段使用R Pod的R及包。远程版本与本地测试环境不同，仍需兼容性验证。
- featureCounts为PE fragment计数、exon/gene_id；链特异性按用户配置unstranded，应保留建库依据。
- DESeq2设计 `~ group`，pairwise Wald/BH，FDR<0.05且abs(log2FC)>1作事后筛选，拟合候选parametric，不自动改变拟合方法或剔除样本。
- 过滤沿用当前legacy_nonzero_fraction=0.75：6样本至少4样本count>0。只在某一组3样本表达的基因可能被过滤，解释结果时必须记录；本轮没有自动改过滤策略。
- GO ORA和GO GSEA启用；GO ALL、minGSSize3/max800、log2FC排序、seed20261027及其余参数以config.yaml为准。
- KEGG=false、custom_analysis=false；resume=false、overwrite=false、standard模式。

## 3. 计划模块与验收

1. 预检查：配置、样本/比较、账号、输入/参考、软件与版本、空间/权限及运行目录冲突。
2. Shell：fastp → STAR → featureCounts → MultiQC；验收每样本日志、BAM可读性、counts样本对应和计数单位、QC表及报告。
3. R：counts严格校验 → 描述性QC → 配置过滤 → 单次DESeq2拟合和本次比较 → GO ORA/GSEA；保存完整结果、NA状态、模型、图和版本。
4. 汇总：区分程序成功、空结果和待解释的科研现象；不得为得到显著结果改阈值。

每次计算使用新的run_id和独立结果目录，禁止覆盖或读取旧prepared包冒充本次结果。若需要程序修改，保留旧快照，生成新的准备包。

## 4. 当前准备状态

- 已完成：本轮2组6样本范围确认；本地CSV及参数字段校验；此前Pod只读存在性/账号检查；旧fastp参数解析与0.21.0版本核实。
- 已交付：`releases/v1_test6_20261027_release.tar.gz`，含代码、配置/元数据快照、入口、中文说明和SHA256清单；以zhangke上传至同名服务器workflow目录并核验。
- 已完成兼容性小测：独立目录中的单样本10,000对reads工具链、人工1,200基因counts的R入口、人工GO阳性气泡图/曲线。新包明确使用fgsea::fgseaMultilevel，避免新版clusterProfiler忽略后端参数；用户排序、阈值和集合范围不变。
- 已补齐环境设置：Shell显式/miniconda3/bin，R固定/usr/bin/Rscript；STAR排序上限4GiB；入口支持校验和、非root身份和基本分离会话/启动锁保护。
- 尚需完成：完整6样本运行前最终执行计划复核及启动授权；小测不保证完整文库质量、真实模型假设或全量内存峰值。
- 当前没有启动完整6样本分析，也没有确认任何真实差异基因或富集结论。小测产物不能当作生物学发现。

最新验收记录见仓库 `docs/07_V1运行包交付与Pod验收.md`。包内analysis_plan.md是构建时快照，后续验收进展以本项目计划和外部报告为准，不手工改写冻结包。

## 5. 后续完整研究范围

原总体研究目标保留：21个小鼠样本、A–G七组、每组三个重复；研究A与其他六组以及B/C、D/E、F/G的比较，并探索C/E/G间转录差异与全组综合表达模式。LRT、表达模式聚类、探索性WGCNA及KEGG属于后续另行设计/实现/验收的内容，不在本轮2组6样本标准测试中自动执行。

总体原始英文描述可在本项目 `backups/config.before_template_account_20261027.yaml` 中追溯。项目ID继续使用xiehe_zhouyisheng_20261018，本地目录和远程20261027目录沿用当前路径，不擅自重命名。

## 6. 本次 Shell 正式启动记录

用户于 2026-10-27 明确授权启动 6 样本 Shell（fastp、STAR、featureCounts、MultiQC）并检查结果，暂不启动 R。已通过冻结包及输入/环境检查，于北京时间 16:52:46 启动 v1_test6_20261027_release，主进程 PID14702，账号 zhangke/UID1482。详细运行记录见 logs/v1_test6_20261027_release/shell_run_record.md。启动仅表示 running，最终结果待验收。本节更新此前准备阶段的未启动状态；R 阶段仍未授权启动。

## 7. Shell 状态核查（2026-10-27 北京时间约17:41）

本运行已于17:17:43失败，第二个样本10GY5FFRT-2的STAR被Killed并返回137。前两样本fastp完成，首样本排序BAM及索引完成；其余四样本、汇总featureCounts与MultiQC未执行。R未启动。容器50GiB内存历史峰值达到限额且存在累计OOM kill，强烈支持内存问题，但尚无该时点内核事件明细。未改参数/Pod，未重跑。证据见 logs/v1_test6_20261027_release/shell_status_check_20261027.md 和 shell_failure_diagnostics.json。

## 8. 更换Pod后的Shell全新运行（2026-10-27）

用户更新Shell Pod为zk2-med-6dc5cbcb5d-wd5lj并授权重新分析6样本，仅Shell，启动后不持续监控。已核实容器zk260818-container内存限制300GiB、CPU64、zhangke/UID1482、共享输入和工具环境。完整配置除shell_pod外与旧包一致，通用代码及样本比较未变；新run_id为v1_test6_20261027_retry01，17:51:51后台启动，PID2174，单次启动核验running且fastp子进程正常。旧失败产物保留，全部样本从fastp全新处理，R未启动。结果待后续按需验收；本次不安排持续监控。详见logs/v1_test6_20261027_retry01/shell_run_record.md。

## 9. Shell验收及R正式启动（2026-10-27）

用户确认Shell完成并授权启动R，稳定运行后结束监控。已核实retry01 Shell于19:43:52成功；6个BAM及索引、57010基因×6样本计数矩阵、Assigned计数和及MultiQC通过检查，证据见logs/v1_test6_20261027_retry01/shell_final_audit.json。R Pod及输入/包/模型检查通过，于20:14:05在原run_id启动R阶段，PID492、zhangke/UID1482。20:14:25检查running，已生成QC、DESeq2对象/差异表/图，进入GO阶段；没有改科研参数、没有重跑Shell。已停止持续监控，最终R验收待后续检查。详见logs/v1_test6_20261027_retry01/r_run_record.md。
