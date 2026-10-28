# 20261027_xiehe_zhou完成核查

检查日期：2026-10-28，北京时间约08:46–08:48。操作为只读远程核查，没有重跑、改参数、修改Pod或覆盖产物。

结论：本次v2.0.0_20261028_run01的Shell及R阶段均已成功完成，主要产物和新目录接口验收通过。研究解释及GSEA警告仍应结合下述记录审阅；本次核查没有创建正式V2 Git标签或推送。

## 阶段与产物

- Shell：succeeded，2026-10-28 02:02:18（北京时间）完成。
- R队列：Shell成功后完成依赖校验，于02:02:52投递R，PID1001。队列状态r_launched_not_completed只是它交接时的记录，不代表当前R仍未完成。
- R：succeeded，02:06:30完成。
- 冻结包逐文件SHA256通过，Shell/R的runtime快照与本次包一致。
- 新布局：results/v2.0.0_20261028_run01/bam_count_data及gene_expr_data/gene_diff_expr，未出现本次运行的旧shell、analysis、de目录。
- 6个排序BAM及索引存在，samtools quickcheck全部通过；STAR唯一比对率90.02%–90.56%。
- 原始计数57010基因×6样本，样本顺序一致，非负整数、非零文库，列总和与featureCounts Assigned一致，MultiQC报告存在。
- PCA、相关性、聚类、DESeq2对象、差异表、MA/火山图、GO ORA/GSEA表/对象/气泡图和HTML报告均存在；HTML中41个相对文件链接全部有效。
- RDS实际模型为~group、parametric，保留23269基因，样本与filtered_counts完全对齐；结果对象明确为10GY5FFRT相对Control的Wald/BH比较。
- 差异基因：上调621，下调231（padj<0.05且abs(log2FC)>1）；pvalue缺失0，padj缺失4963，保留在完整结果中，未为了富集删改。
- GO GSEA：14685条返回通路，157条padj<0.05；上调GO ORA显著419条，下调27条。

## V1对照

与旧运行v1_test6_20261027_retry01对应文件比较：原始计数矩阵、完整差异表和显著差异表均SHA256完全一致。

原始计数SHA256：0e163c0e49aca82261962eedf8cd461173b3841957fe576d3132416505a28654。

这证明当前比较的核心数值结果未因目录修改发生变化；未据此声称原始FASTQ/BAM全内容逐字节一致或每个富集结果均已独立审阅。

## 日志警告

- GSEA排序使用18393基因，430个重复分数（约2.34%）；按既定ID规则排序并记录，未添加抖动或改变排序指标。
- fgsea提示8条通路因正负统计量不平衡而无法可靠估计，pval/padj/NES等为NA，保留原状：GO:0000785、GO:0006325、GO:0006412、GO:0016071、GO:0051248、GO:0140640、GO:0160307、GO:1990904。它们不能解释为显著或不显著的可靠检验结果。
- 某些P值低于既定eps=1e-10；没有自动将eps改零或增加nPermSimple（保持1000）。
- DESeq2提示Control不是默认参考水平；实际results显式指定10GY5FFRT vs Control，已通过结果对象的描述核对方向。
- 注释存在一对多映射提示，映射表已保存。samtools原环境ncurses版本提示仍存在，但quickcheck返回0。

GSEA实际后端fgsea::fgseaMultilevel 1.38.0，seed20261027、集合大小3–800、scoreType=std、exponent=1、sampleSize=101，与本次既定配置及代码一致。

## 路径与证据

服务器报告：/home/zhangke/RNA-seq/20261028_xiehe_zhou/results/v2.0.0_20261028_run01/gene_expr_data/report.html。

本地原始证据：completion_snapshot.json（状态、日志与文件清单）、completion_audit.json（Shell/路径/对照核查）、r_final_audit.json（模型和GO核查）。冻结包及其历史分析计划不修改；后续进展以本报告及项目计划为准。
