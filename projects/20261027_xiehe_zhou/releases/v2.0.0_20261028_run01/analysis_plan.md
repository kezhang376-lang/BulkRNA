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
