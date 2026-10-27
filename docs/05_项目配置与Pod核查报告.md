# 当前项目配置与 Pod 只读核查报告

日期：2026-10-27。对象：`projects/20261018_xiehe_zhou/config.yaml` 及关联元数据。

结论：主要服务器目录、参考和 fastp 配置均存在，两个 Pod 可用，且可切换至 zhangke；但配置仍有确定错误和执行阻断，尚不能正式启动。本次未修改配置、CSV、远程文件、Pod 或软件环境，未执行 fastp/STAR/DESeq2 等分析任务。

## 1. 必须先解决的问题

| 严重性 | 位置 | 核查事实 | 处理方式 |
|---|---|---|---|
| 阻断 | config.yaml:15–16 | `context: renkelab-zhangke` 不存在；`namespace: default` 查询被服务端拒绝 | 实际应为 `context: zhangke@med.thu`、`namespace: renkelab-zhangke`；已用这组值找到两个指定Pod。本轮仅报告，未代改 |
| 阻断 | config.yaml:61 | YAML可解析，但 schema 报 `config.fastp.extra_args: expected array`；此字段填成了旧配置文件路径 | 当前代码要求CLI参数数组，不能直接读取旧 wrapper 的配置格式。必须实现兼容解析或按已确认原参数转换，并明确二进制版本，不直接改为默认空数组掩盖差异 |
| 阻断 | samples.csv、contrasts.csv | 标题及每条数据被“整行引号”包住，分别读为6行×1列、1行×1列 | 改成逐字段的正规CSV；不得把整行当一个单元格。当前还无法完成正式样本/比较字段校验 |
| 阻断 | config.yaml:7、metadata | 描述是21样本/7组；本地只有6条样本记录，远端输入也只有12个FASTQ，即6个PE样本 | 明确本轮是先做6样本，还是完整21样本；补齐对应输入和完整元数据，不自动补造样本 |
| 阻断 | samples.csv | 未提供 `fastq_r1,fastq_r2`，当前通用代码要求显式文件映射 | 按已核实文件名填写；不能只修CSV引号而漏掉FASTQ列 |
| 阻断 | config.yaml:91 | `resume: true` 是有效布尔值，但当前 v1 未实现指纹验证的恢复 | 选择实现恢复功能，或明确本轮为全新运行后设false；不得偷偷忽略或改值 |
| 阻断 | config.yaml:44 | KEGG需求保留为true，当前代码未实现该模块 | 先实现/验收，或明确本轮范围后调整；不是路径不存在造成的问题 |
| 范围待落实 | config.yaml:7、73；analysis_plan.md | description包含LRT、组间综合表达模式及探索性WGCNA，现有代码只做pairwise Wald，计划文件为空 | 研究描述不等于已实现流程；把本轮比较、模型和后续可选模块分开写入计划，不能认为 `~ group` 会自动触发LRT |

本地 YAML 语法解析通过；按当前 schema 做字段校验时，仅发现1项类型错误（fastp.extra_args）。这不代表语义和输入通过：namespace/context字段虽然类型正确，真实连接仍错误；resume和KEGG也需要单独的代码能力检查。

## 2. 已核实的连接、账号和资源

实际连接配置应为：

```yaml
kubernetes:
  context: "zhangke@med.thu"
  namespace: "renkelab-zhangke"
  shell_pod: "zk1-med-6ff4f46898-rlbtd"
  r_pod: "zkr1-med-5d8b8c5b48-tggbt"
  account: "zhangke"
```

| 项目 | Shell Pod | R Pod |
|---|---|---|
| 状态 | Running | Running |
| 容器 | zk250904-container | zkr250903-container |
| 默认exec身份 | root / UID0 | root / UID0 |
| 经runuser切换 | zhangke / UID1482 / GID1001 | zhangke / UID1482 / GID1001 |
| CPU request / limit | 8 / 50 | 8 / 64 |
| 内存 request / limit | 50Gi / 50Gi | 50Gi / 300Gi |

仅先核验默认身份，再用 `runuser -u zhangke -- ...` 执行数据、参考和工具检查。没有以root读取项目数据或执行分析。账号存在且UID非0已实际验证；入口保护与实际切换方式可衔接，但还没有远程自动执行器。

12线程没有超过所见CPU limit，但超过8核CPU request；调度时不保证独占12核。Shell Pod的内存limit是50Gi，当前未做STAR加载或排序内存峰值验证，也未为排序显式配置内存上限，不能仅凭12线程认为资源已验收。

## 3. 文件和目录存在性

以下配置路径在两个 Pod 中均可由 zhangke 访问：

| 配置位置 | 实际类型与状态 |
|---|---|
| input_dir `/home/zhangke/RNA-seq/20261027_xiehe_zhou/raw_data` | 目录存在、可读，12个FASTQ |
| output_dir `/home/zhangke/RNA-seq/20261027_xiehe_zhou/results` | 目录存在，权限检查可写；未实际写入测试文件 |
| counts_file `/home/zhangke/RNA-seq/20261027_xiehe_zhou/counts_data` | **目录**，不是counts矩阵文件；当前type=fastq时不参与读取，非当前主流程阻断。可留null作未使用项；将来type=counts必须指向具体TSV文件 |
| reference_dir `/home/zhangke/public_database` | Shell Pod确认存在、可访问；下列具体参考在两Pod可读 |
| references.fasta | 文件存在、可读，2,773,696,683字节；FASTA头包含GRCm39 |
| references.gtf | 文件存在、可读，886,682,056字节；头部genome-build/genome-version均为GRCm39 |
| references.star_index | 目录存在；Genome、SA、SAindex、genomeParameters.txt、chrName.txt、sjdbInfo.txt均存在、非空、可读（Shell侧详细检查） |
| `/home/zhangke/soft/fastp_dir/Illumina_fastp.config` | 文件存在、可读，274字节 |
| `/home/zhangke/soft/fastp_dir/start_fastp.py` | 文件存在、可读，2780字节；只阅读，未执行 |

FASTA、GTF、index路径与小鼠/GRCm39标签在命名和所读头部层面一致；没有计算完整大文件哈希，不能把存在性等同于完整参考一致性证明。

STAR索引元数据记载 `versionGenome=2.7.4a`、`sjdbOverhang=100`，所记录FASTA/GTF使用历史前缀 `/home/wanglihui/zhangke/...`；这些历史文件路径当前不存在。目录搬迁可以产生这种情况，本身不能判为索引损坏。没有足够证据确认它们与当前参考的完整内容一致；`versionGenome`也不能直接当作生成程序版本。实际STAR为2.7.11b，兼容性还未通过加载/小规模比对测试，本轮没有加载大索引。

## 4. 跨 Pod 存储

Pod定义中 `/home/zhangke` 的直接NFS挂载指向相同服务端和相同导出路径（并非PVC）。两侧对应文件/目录的inode、大小、mtime相同，能看到相同12个FASTQ；不同容器的device编号不同是挂载视图差异，不据此判定不共享。

已确认共享的NFS来源与现有文件可见性；没有做写入标记测试，也没有检查个人配额。共享NFS的df使用率显示99%，但仍显示较大共享空闲空间；全盘数字不是个人额度，不能据此保证本项目有足够输出空间。

## 5. 已核实 FASTQ 清单

| sample_id | R1 | R2 |
|---|---|---|
| 10GY5FFRT-1 | 10GY5FFRT-1_1.fq.gz | 10GY5FFRT-1_2.fq.gz |
| 10GY5FFRT-2 | 10GY5FFRT-2_1.fq.gz | 10GY5FFRT-2_2.fq.gz |
| 10GY5FFRT-3 | 10GY5FFRT-3_1.fq.gz | 10GY5FFRT-3_2.fq.gz |
| control-1 | control-1_1.fq.gz | control-1_2.fq.gz |
| control-2 | control-2_1.fq.gz | control-2_2.fq.gz |
| control-3 | control-3_1.fq.gz | control-3_2.fq.gz |

12个文件都可打开、非空，前2字节均符合gzip标记。没有解压全文件、验证CRC、完整FASTQ记录数或序列配对一致性；这些检查尚未完成。没有在该输入目录中发现其余15个样本。

## 6. 软件环境与 fastp 参数

### 工具可用性

Shell账号通过 `runuser -u zhangke -- python3 ...` 的普通非登录环境，PATH找不到fastp/STAR/featureCounts/samtools/MultiQC。使用 zhangke 的登录shell后，这些工具都可见于 `/miniconda3/bin`。因此启动器需明确初始化相同环境，不能只切换UID就认定软件可用。

| Shell登录环境工具 | 实际版本 |
|---|---|
| fastp | 0.23.4 |
| STAR | 2.7.11b |
| featureCounts | 2.0.6，帮助信息支持 `--countReadPairs` |
| samtools / htslib | 1.21 / 1.21 |
| MultiQC | 1.30 |

R Pod直接由zhangke调用的 `/usr/bin/Rscript` 为R4.6.0。所需包目录与版本均可查询：DESeq2 1.52.0、edgeR 4.10.0、ggplot2 4.0.3、pheatmap 1.0.13、clusterProfiler 4.20.0、AnnotationDbi 1.74.0、enrichplot 1.32.0、org.Mm.eg.db 3.23.0、BiocParallel 1.46.0、yaml 2.3.12、jsonlite 2.0.0。

本轮只查询版本，没有安装、升级、加载全部包做兼容性测试或运行统计分析。本地旧版本的模拟测试不能直接证明这些远程新版本已验收；OrgDb版本也不是Ensembl_109注释的同义词。

### 旧fastp配置实际内容

```text
fastp /home/zhangke/soft/fastp_dir/fastp
adapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA
adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT
trim_front1 0
trim_front2 0
qualified_quality_phred 20
unqualified_percent_limit 30
average_qual 20
length_required 20
```

旧wrapper读取上述键值并拼接CLI，且使用第一行指定的程序；该具体程序实际版本为0.21.0。新脚本使用PATH中的fastp，为0.23.4。两者不能静默视为完全等价。

目前准备器的extra_args白名单还没有 `--trim_front1`、`--trim_front2`、`--average_qual`；即使把文件内容直接改成数组，完整旧参数仍不能直接通过。这是需要补齐的兼容实现，不能靠删除参数让流程通过。

## 7. 方法与范围提示（不自动修改）

- `unstranded` 是代码支持的取值，本轮不能通过文件名/gzip头证明建库链特异性；应以建库记录为依据。
- `legacy_nonzero_fraction=0.75` 按现有代码在21样本时要求至少15个样本非零；只在某一3样本组表达的基因会被排除。在目前6样本时则要求至少4个样本非零。需结合最终样本范围确认，不能自动换规则。
- FDR0.05、log2FC阈值1、parametric拟合、GO大小范围和GSEA排序字段均在当前支持范围内；合法取值不等于已完成方法学验收，不擅自改动。
- minGSSize=3较小、log2FC排序及GO ORA背景沿用审查版候选，应在项目计划中明确。本轮不以“没有报错”替代科研方案确认。
- 本地目录日期20261018、project.id和远程路径日期20261027不同，不是语法错误，现有远端目录确实存在，仍应明确项目命名约定。

## 8. 下一步顺序

1. 确定本轮真实范围为6样本还是21样本，修正CSV格式并补齐FASTQ映射和比较表。
2. 修正context/namespace，明确本轮是否需要恢复执行及KEGG；按需求补齐代码，而非静默关闭功能。
3. 对旧fastp配置增加受验证的兼容方式，明确程序版本及登录环境初始化。
4. 写入分析计划，明确过滤、比较和当前/后续模块。
5. 重新生成含账号保护的新审查包，做授权的小规模兼容验证，再申请本次正式启动确认。

本次仅新增核查报告，未替用户修正配置。旧prepared/review_v1、review_v2仍不应执行。
