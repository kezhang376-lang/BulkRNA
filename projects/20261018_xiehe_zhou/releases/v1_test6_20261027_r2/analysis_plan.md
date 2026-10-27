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
- 本次将生成：包含当前代码/配置/元数据的本地准备包及review_plan.md，不上传、不启动。
- 尚需完成：实际执行入口的登录环境初始化、远程新包依赖/兼容性和资源检查，以及正式启动前的最终执行计划复核。
- 当前没有启动计算，也没有确认任何差异基因或富集结论。

## 5. 后续完整研究范围

原总体研究目标保留：21个小鼠样本、A–G七组、每组三个重复；研究A与其他六组以及B/C、D/E、F/G的比较，并探索C/E/G间转录差异与全组综合表达模式。LRT、表达模式聚类、探索性WGCNA及KEGG属于后续另行设计/实现/验收的内容，不在本轮2组6样本标准测试中自动执行。

总体原始英文描述可在本项目 `backups/config.before_template_account_20261027.yaml` 中追溯。项目ID继续使用xiehe_zhouyisheng_20261018，本地目录和远程20261027目录沿用当前路径，不擅自重命名。
