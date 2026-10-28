# 20261027_xiehe_zhou：2.0目录接口全流程验证

用户于2026-10-28明确授权启动Shell与R两个阶段；确认后台任务正常后停止本地持续监控。配置项目ID为xiehe_zhouyisheng_20261027；本地目录20261027，配置指定服务器目录20261028，按用户配置保留。

- 流程代码：当前2.0.0开发代码，尚未发布Git标签；run_id=v2.0.0_20261028_run01。
- 输入：服务器/home/zhangke/RNA-seq/20261028_xiehe_zhou/raw_data，10GY5FFRT-1/2/3、control-1/2/3，共12个FASTQ；组别与比较由CSV决定。
- 输出：/home/zhangke/RNA-seq/20261028_xiehe_zhou/results/v2.0.0_20261028_run01，包含bam_count_data和gene_expr_data/gene_diff_expr，无runs层。
- Shell：fastp0.21.0及旧参数配置、STAR、samtools检查/索引、PE fragment featureCounts、MultiQC。各工具12线程，STAR BAM排序内存4GiB；Shell Pod限额300GiB/64CPU，指定账号zhangke。
- R：样本QC、6样本至少4样本非零过滤、~group、DESeq2 Wald/BH、parametric拟合、FDR0.05及abs(log2FC)>1；GO ORA/GSEA按现有配置，GO ALL、集合3–800、log2FC排序、seed20261027。KEGG和custom禁用，不改科研参数。
- Shell与R分别使用配置指定Pod，共享路径；不把R统计提前与Shell并发执行。
- 本项目额外提供独立的R依赖等待脚本，冻结进本次运行包：在R Pod后台等待Shell成功后验收counts/6样本产物，调用已有R后台入口。Shell失败则停止；最多等待48小时；不自动重试、恢复或修改参数，不需要本地Codex持续在线。
- 运行前检查身份、Pod、存储、环境、配置、输入和新目录冲突；整个包上传后在两个Pod核对SHA256与非root身份。
- 完成标准：Shell/R均成功，输入输出结构及比较方向正确，报告链接和新目录规则一致。若与V1输入内容及环境一致，应对照计数、QC及统计结果，解释非预期差异；仅同名/同大小不证明输入内容一致。
- 本次启动不等于结果验收通过；V2正式发布、更新版本清单、Git提交及GitHub同步均待验证成功后执行，保留V1及旧产物。

## 本次投递状态

2026-10-28北京时间00:16:55启动Shell，PID4053；00:17:07投递R Pod依赖等待任务，PID958。启动后检查Shell running且fastp子进程正常、R等待状态waiting_for_shell，两者均zhangke/UID1482；R统计尚未开始。19项Python检查、双Pod环境及包校验和入口语法检查通过。已按用户要求结束本地持续监控。最终结果未验收，2.0尚未正式发布。详见logs/v2.0.0_20261028_run01/run_record.md。

## 完成核查（2026-10-28）

只读核查确认Shell于北京时间02:02:18、R于02:06:30成功完成；R队列自动衔接已实现且有依赖验收。6个BAM quickcheck、57010×6计数及Assigned、报告41个链接、新目录结构通过；R实际~group/parametric模型，23269基因，上调621/下调231。原始计数、完整及显著差异表与V1 SHA256一致。GSEA有8条通路统计量NA、约2.34%排序ties和eps下限警告，已记录，不改参数或重跑；流程成功不替代科研解释。本次未发布Git V2。详细证据见logs/v2.0.0_20261028_run01/completion_report.md。

## 正式发布授权（2026-10-28）

用户在完成验收后明确要求正式发布V2、更新文档、本地Git保存并上传GitHub。正式版本2.0.0，标签v2.0.0，分支main。分析内核和本项目队列与已验收包保持一致；发布前仅修复后续生成中文说明的编码、增加回归检查及发布文档。实际运行包和服务器结果不改写，GSEA已知警告保留。发布范围和证据见docs/10_V2发布说明与验收记录.md及docs/releases/v2.0.0.json。
