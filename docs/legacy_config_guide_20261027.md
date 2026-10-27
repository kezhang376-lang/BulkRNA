> 历史说明：这是Git基线建立前的配置填写初稿，保留用于追溯。文中的占位值、未实现状态和建议字段不代表V1现状；当前入口见根README.md，实际支持字段以schemas/config.schema.json为准。

# BulkRNA 配置填写与准备指南

本项目在 Windows 保存代码、配置和运行记录，在用户手动准备的 Shell Pod、R Pod 中执行计算。当前已交付两组6样本的V1独立运行包，并完成目标Pod环境与小规模工具链/R统计/GO绘图兼容性核验；完整6样本分析尚未启动。V1提供基本后台启动保护，模式B/C、指纹复用及完整队列调度尚未完成。仅填写 YAML 或将模块设为 true 不表示模块已实现。

**当前推荐运行包**：[v1_test6_20261027_release.tar.gz](projects/20261018_xiehe_zhou/releases/v1_test6_20261027_release.tar.gz)。操作见[项目中文运行说明](projects/20261018_xiehe_zhou/运行说明_V1.md)，验证证据和范围见[V1交付与Pod验收报告](docs/07_V1运行包交付与Pod验收.md)。历史审查记录保留原日期和当时状态，不能替代当前验收报告。

最新代码范围、相对旧脚本的方法差异、使用命令和待确认项见 [通用代码初版审查指南](docs/02_通用代码初版审查指南.md)。本 README 后面的新增字段有部分是未来接口建议；**本版实际支持范围以 `schemas/config.schema.json` 和初版审查指南为准**，不要把未支持字段直接填入并认为已生效。

本地测试结果见 [初版验证记录](docs/03_初版本地验证记录.md)。账号约束与项目配置升级见 [配置升级记录](docs/04_项目配置升级与账号约定.md)。`prepared/review_v1`、`review_v2` 是旧配置/代码快照，已不能代表当前项目，禁止直接用于本次运行；补齐输入后重新生成审查包。

最新补充：[fastp旧配置兼容与核查](docs/06_fastp旧配置兼容与最新核查.md)。`fastp.extra_args` 现可直接填写旧键值配置路径，程序使用文件内指定的二进制和参数；当前项目按用户要求固定为0.21.0。早期报告中“仅接受数组”的限制已在本次兼容中解除。

本文基于 `projects/20261018_xiehe_zhou/config.yaml` 的当前内容解释。原始脚本审查见 [详细审查报告](docs/01_代码审查与重构方案.md)。当前用户配置、样本表、比较表和原始脚本仍保留，未访问学校服务器。

## 1. 配置文件与填写规则

- `config/defaults.yaml`：通用配置模板，不应长期保存某一次运行的真实 Pod 名。
- `projects/<项目名>/config.yaml`：项目专属配置，保存实际项目、输入、参考和分析设置。
- `samples.csv`：样本身份与实验设计；`contrasts.csv`：比较方向；两者不应由 YAML 中的描述替代。
- `analysis_plan.md`：记录待确认科研方案、模块范围、验收状态及定制需求。

建议未来加载规则为“默认配置 → 项目配置”，按嵌套键合并，项目值覆盖默认值，数组整体替换，未知字段报错；这只是待实现的接口约定。执行前保存最终合并配置快照，不允许静默使用占位值。安全关键项如物种、参考、样本表和链特异性不能靠通用模板猜测。

YAML 使用空格缩进，不用 Tab；同层字段对齐，避免重复键。布尔值写 `true`/`false`，数字不加引号，未知值写 `null`，不要用字符串 `"null"`。Linux 路径使用 `/`；Windows 路径建议也使用 `/` 或单引号，避免双引号中的反斜杠转义。所有下方新增字段均为建议，须待 schema 和加载器实现后才会生效。

## 2. 当前 config.yaml 每项含义与示例

### project：项目身份

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `project.id` | `BulkRNA_001` | 稳定且唯一的项目标识，建议改为 `20261018_xiehe_zhou` 与目录对应；运行批次另用 run_id，避免每次运行都改项目 ID |
| `project.description` | `Treatment vs Control` | 人类可读说明，例如 `10GY5FFRT vs Control，小鼠 Bulk RNA-seq`。描述不参与分组或比较，处理条件、物种应经确认后填写 |

### kubernetes：远程执行位置

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `kubernetes.namespace` | `default` | 两个 Pod 所属命名空间；以实际值为准，不是 Windows 文件夹 |
| `kubernetes.shell_pod` | `shell-pod-name` | Shell Pod 实际名称，执行 fastp、STAR、featureCounts 等；当前是占位值，每次 Pod 变化后更新 |
| `kubernetes.r_pod` | `r-pod-name` | R Pod 实际名称，执行统计和绘图；当前是占位值，每次 Pod 变化后更新 |
| `kubernetes.account` | 通用模板为 `null`，当前项目为 `zhangke` | Pod 内的非 root Linux 执行账号。必须先切换至该账号；Shell/R 入口校验用户名及 UID，身份不符立即停止；不是 kubectl 集群认证用户名 |

Pod 由用户手动创建。工作流不创建、删除 Pod 或修改 Pod 配置；配置中不保存证书、token、密码或 kubeconfig 原文。还建议增加 context；多容器 Pod 需要分别指定 container，见第 5 节。

配置版本说明：本节以下“当前值”和样本核查是初次填写时的历史记录。项目已更新为新的项目描述和真实 Pod 名，最新状态以项目 config.yaml 与配置升级记录为准，历史样本核查不代表本次准备已通过。

### species：物种与参考版本

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `species.name` | `mouse` | 物种标识，小鼠示例 `mouse`；后续映射到小鼠 OrgDb 和富集数据库标识。必须与真实样本一致 |
| `species.genome` | `GRCm39` | 参考组装版本；不能与 GRCm38/mm10 混用 |
| `species.annotation` | `Ensembl_109` | 注释来源和发布版本；不等于已经指定 GTF 文件，也不证明 STAR index 使用了该注释 |

组装、FASTA、GTF、STAR index 需相互兼容。后续保存参考校验信息和 index 生成记录，不能仅凭目录名称核实。

### paths：服务器数据位置

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `paths.input_dir` | `/home/zhangke/RNA-seq/project001/raw_data` | 原始输入目录；当前是模板路径。若实际如此，可填 `/home/zhangke/RNA-seq/20261018_xiehe_zhou/raw_data`，需随后核验 |
| `paths.output_dir` | `/home/zhangke/RNA-seq/project001/results` | 项目结果根目录；建议实际项目路径下的 `results`，每次运行再建独立 run_id 子目录，避免新旧结果混用 |
| `paths.reference_dir` | `/home/zhangke/public_database` | 参考数据库总目录；不能替代明确的 FASTA、GTF 和 index 路径 |

这些是 Pod 中的 Linux 路径，不是 Windows 本地路径。两个 Pod 同名路径不保证底层共享；可能还需各自的项目挂载路径。输入目录禁止覆盖写入；输出目录不得指向原始 FASTQ 目录。

### input：输入类型和测序布局

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `input.type` | `fastq` | 本次从原始 FASTQ 开始。模式 C 未来可支持 `counts` 或 `existing_results`，但这些枚举及其必需字段尚未实现，不能直接改值后认为可运行 |
| `input.paired_end` | `true` | 双端测序，每个文库需要对应 R1、R2；单端才写 `false`。不要根据文件数量猜测，也不代表链特异性已确定 |

当前还缺每样本 FASTQ 文件映射、链特异性、lane/技术重复等信息。`sample_id` 不足以推导文件名，后续须显式提供 R1/R2。

### analysis：要执行的模块

这些字段表达分析意图，不能自动补足依赖。上游禁用而下游启用时，必须验证有可复用的匹配结果，否则停止。

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `analysis.fastp` | `true` | FASTQ 过滤及接头处理。使用已处理 FASTQ 时可按方案设 false，但必须声明输入来源和 QC |
| `analysis.star` | `true` | 使用 STAR 比对。模式 C 禁止重跑时需显式禁止执行，不能仅靠 resume |
| `analysis.featurecounts` | `true` | 从 BAM 生成基因 counts；需 GTF、计数单位和链特异性配置 |
| `analysis.sample_qc` | `true` | counts 统计、表达分布、PCA、相关性和样本聚类等计划中的 QC；当前原始 R 脚本未完整实现全部项目 |
| `analysis.differential_expression` | `true` | 按样本表、设计和比较表进行 DESeq2 分析 |
| `analysis.go_enrichment` | `true` | 建议专指 GO ORA（过度富集分析），与 GO GSEA 区分；当前字段自身没有定义方法，原始脚本只实现 GO GSEA，ORA 尚未实现，需在方案中确认 |
| `analysis.kegg_enrichment` | `true` | 计划进行 KEGG 富集；还需区分 ORA/GSEA、物种代码、ID、数据库来源与版本。原始脚本未实现该模块 |
| `analysis.gsea` | `true` | 排序基因集富集；当前不能从此开关判断是 GO、KEGG 还是 Hallmark，需补充基因集与排序参数；原始脚本为 GO GSEA |
| `analysis.custom_analysis` | `false` | 是否有项目专属分析；模式 B 确认分析计划后启用，脚本和结果放在本项目 `custom/` 下 |

### deseq2：模型与结果筛选

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `deseq2.design` | `~ group` | 只建模实验组；`group` 必须是样本表列名。独立样本且无需其他协变量时可用。确认存在可估计的批次效应后可用 `~ batch + group`；配对样本可能用 `~ subject + group`，需先核实设计、混杂和模型满秩 |
| `deseq2.fdr` | `0.05` | 计划以 BH 调整后的 p 值（padj）作为显著性标准，阈值 0.05；不是原始 pvalue 0.05。实施时应同步配置 results 的 alpha，并明确边界使用 `<` 还是 `<=` |
| `deseq2.log2fc_cutoff` | `1` | log2 倍数变化幅度阈值，1 对应约2倍上调或降至1/2；与 padj 条件一起筛选。原脚本是 FC=1.5、原始 p<0.01，使用此配置会改变结果，需要在计划中明确记录 |

建议先明确采用普通 Wald 检验后按效应值筛选，还是直接检验效应是否超过阈值；两者不是同一种假设检验。不能把 `log2fc_cutoff` 自动传成另一种统计检验，也不能静默启用 LFC shrinkage。正负方向由 contrasts.csv 明确，不能依赖字母排序的默认参考水平。

有关设计、contrast 和独立过滤的依据见 [DESeq2 官方指南](https://www.bioconductor.org/packages/release/bioc/vignettes/DESeq2/inst/doc/DESeq2.html)。

### execution：执行与结果保护

| 字段 | 当前值 | 含义及填写示例 |
|---|---|---|
| `execution.resume` | `true` | 计划复用已成功且输入、配置、代码、参考和软件版本匹配的模块；文件存在或名字相同不够。当前尚无复用实现 |
| `execution.overwrite` | `false` | 不覆盖已有结果；重跑写入新的 run_id。它不等于禁止重算，模式 C 还需单独声明禁跑模块 |
| `execution.mode` | `standard` | 模式 A 的建议标识；模式 B/C 可分别约定为 `standard_custom`/`reuse`，这些取值需要 schema 和调度器支持后才有效 |

建议优先级：先检查显式禁跑模块，再判断是否能复用，最后才判断是否允许计算；缺失已有结果时不得擅自重跑用户禁止的步骤。当前没有统一启动器，请勿把本文件理解为已经具备一键执行功能。

## 3. 当前样本表和比较表核查

2026-10-27 本地读取结果：

- `samples.csv`：6 个样本，sample_id 无重复；`10GY5FFRT` 和 `Control` 各 3 个。
- 样本为 `10GY5FFRT-1`、`10GY5FFRT-2`、`10GY5FFRT-3`、`control-1`、`control-2`、`control-3`。样本 ID 的大小写与组名是不同概念，保留原样，不自动替换字符。
- `contrasts.csv`：1 个比较，ID 为 `10GY5FFRT_vs_Control`，treatment=`10GY5FFRT`，control=`Control`；两组都存在且互不相同。
- 拟定方向：正 log2FC 为 `10GY5FFRT` 相对 `Control` 上调。
- 两份文件扩展名是 `.csv`，实际分隔符是 Tab。若用默认逗号读取会误读。建议后续统一为 UTF-8 的逗号 CSV，或保留 Tab 并在配置声明分隔符；本轮未改变文件。
- 数量对应不等于已确认生物学独立性，尚需确认是否独立生物学重复、配对、批次、lane 或技术重复；未检查 FASTQ 或 counts 的对应关系。

当前列规范：samples 使用 `sample_id,group`，contrasts 使用 `contrast_id,treatment,control`。后续加载器应支持这套真实字段，不直接套用旧脚本的无表头格式，也不静默改成另一套列名。

## 4. 正式分析前尚未满足的条件

| 项目 | 当前状态 | 下一步 |
|---|---|---|
| 项目 ID/描述 | 通用模板 | 填实际项目标识和条件描述 |
| Pod、context、挂载与资源 | Pod 为占位名，其他未核实 | 执行阶段用户准备 Pod 后检查 |
| FASTQ 根目录和结果目录 | 仍为 project001 模板路径 | 提供实际目录；核对配对及权限 |
| 样本到 FASTQ 映射 | 未提供 | 增加 R1/R2 路径列或独立 FASTQ/lane 清单 |
| 实验设计 | 两组各3样本，独立性及批次未知 | 用户确认重复、配对、批次及协变量 |
| 物种、建库、链特异性 | YAML 写 mouse/PE，未独立确认 | 提供实验/建库信息，不推测 |
| 参考文件 | 只有总目录和标签 | 明确 FASTA、GTF、index 及生成版本 |
| fastp 行为 | wrapper 和配置未提供 | 补充 start_fastp.py、实际 config 或确认新的参数方案 |
| 统计参数 | YAML 为 FDR 0.05、log2FC 1，与旧脚本不同 | 在 analysis_plan.md 记录正式方案和筛选规则 |
| ORA/GSEA | 方法、基因集、背景及映射策略不全 | 确认需实现哪些模块和参数 |
| 执行器和预检查 | 尚未实现 | 先实现计划/验证，再做小规模测试 |

## 5. 建议补充的配置项

以下是需要补齐的接口设计，不是已写入配置的默认值。未知的科研参数保留 null，预检查应拒绝在必需项未知时启动。

### 5.1 首次正式执行前必须明确

| 建议字段 | 含义与填写示例 | 注意事项 |
|---|---|---|
| `schema_version` | 配置格式版本，例如 `"1.0"` | 版本由实现统一定义 |
| `metadata.samples` | `"samples.csv"` | 相对项目 config.yaml 所在目录解析，不随当前工作目录变化 |
| `metadata.contrasts` | `"contrasts.csv"` | 同上 |
| `metadata.delimiter` | 当前文件可用 `"\t"`，逗号 CSV 用 `","` | 显式声明，加载器验证真实列数和表头 |
| `kubernetes.context` | 实际集群 context 名称 | 防止选错集群，不保存认证信息 |
| `kubernetes.shell_container` / `r_container` | 多容器 Pod 中的实际容器名 | 单容器时可省略 |
| `paths.shell_project_root` / `r_project_root` | 两个 Pod 各自看到的项目根路径 | 共享存储检查后确定；不是强制两者相同 |
| `references.fasta` / `gtf` / `star_index` | 参考的准确绝对路径 | 原脚本路径可作候选，不当作已验证路径 |
| `references.gene_id_type` | Ensembl gene ID 示例 `"ENSEMBL"` | 确认是否有版本后缀，保留原始 ID |
| `references.orgdb` | 小鼠示例 `"org.Mm.eg.db"` | 同时记录实际包版本；与物种匹配 |
| `input.strandedness` | 待确认 `null`；约定 unstranded/forward/reverse | 不默认 unstranded。featureCounts 对应 -s 0/1/2，须按建库和软件验证 |
| `featurecounts.count_unit` | PE 目标通常需明确为 fragment 或 read | 不能仅根据 -p 判断计数单位，版本差异见官方说明 |
| `featurecounts.feature_type` / `gene_attribute` | 原脚本 `"exon"`、`"gene_id"` | 需要确认 GTF 实际字段 |
| `resources.star_threads` / `featurecounts_threads` / `r_threads` | 示例为各工具所需线程数 | 按 Pod 限额分配，不直接照搬本地 CPU 核数 |
| `execution.run_id` | 示例 `"20261027_run01"` | 仅示例，实际启动时唯一；所有产物需归属于一次运行 |
| `execution.dry_run` | 准备阶段建议 `true` | 计划模式仅本地校验/生成计划；远程只读预检应显式独立，不产生计算任务 |

FASTQ 映射建议在 samples.csv 增加 `fastq_r1,fastq_r2`；相对路径以 input_dir 为基准，绝对路径直接使用。每样本多个 lane 时使用单独文库/lane 表，不能把同一生物学样本拆成多个统计重复。批次和配对信息放入样本表，而不是复制到一串 YAML 组名里。

有关链特异性和 read-pair 计数见 [featureCounts 官方说明](https://subread.sourceforge.net/featureCounts.html) 和 [Subread 版本说明](https://subread.sourceforge.net/)。

### 5.2 方法确认后补充

- `filtering.method` 及相应参数：明确低表达过滤规则，不默认沿用原始“全样本75%非零”规则，也不静默改为其他方法。
- `fastp` 参数/配置文件和版本：接头、质量、最短长度、PE 配对处理；wrapper 如保留，也需记录路径与代码指纹。
- `featurecounts` 的多重比对、重叠基因和配对处理策略：先定义科学口径，再填参数，避免随意加 -M/-O/-B/-C。
- `deseq2` 的检验类型、padj 方法、LFC 来源、阈值边界：建议明确 `padj < 0.05` 与 `abs(log2FoldChange) > 1` 是否为最终规则；是否 shrinkage 或做效应阈值检验需另行确认。
- `enrichment.go`：ORA/GSEA、BP/MF/CC/ALL、ID 类型、FDR、基因集大小；ORA 的背景为本次可检验且能映射的基因，不能默认全基因组。
- `enrichment.kegg`：分析方法、物种代码（小鼠通常为 mmu）、ID 转换、数据库来源、获取日期/版本及在线可用性；当前未执行数据库连接核验。
- `enrichment.gsea`：基因集来源、排序指标（如 Wald stat 或 log2FC，需确认）、唯一 ID 规则、重复/ties 处理、seed、backend 和参数。使用完整有效排序结果，不能仅用显著基因。
- `qc`：PCA/距离所用表达变换、异常提示规则、批次可视化。异常提示不自动触发剔除样本。

### 5.3 三种模式的补充

| 模式 | 建议字段与行为 |
|---|---|
| A 标准 | `execution.mode: standard`；本次启用模块及依赖均能满足，预检通过后才可启动 |
| B 标准加定制 | 建议 `standard_custom`，加 `custom.plan_file: analysis_plan.md`；记录人工确认后的计划指纹。专属脚本/结果位于 custom，不改标准模块 |
| C 已有结果续分析 | 建议 `reuse`，增加已有 run 的 manifest 路径、明确 counts/DESeq2/GSEA 对象路径、`execution.forbid_modules` 列表；缺少匹配结果时停止，不自动重跑被禁止模块 |

模式 C 不能只比较文件名或只比较整个配置是否完全相同；需要按模块依赖判断哪些参数影响该产物。例如新增 Reactome 绘图不应使原先匹配的 STAR BAM 失效，而改变参考 index 应使相关下游结果失效。复用记录应保存输入校验信息、参考、参数、代码和软件版本、成功状态及输出清单。

### 5.4 运行记录和可复现性

manifest 自动记录执行时间、实际 Pod/软件版本、配置快照、代码版本/指纹、参考指纹、输入文件信息、模块退出码与结果状态；用户不必手填每项。大 FASTQ/BAM 的完整哈希成本较高，校验策略需明确，不能以文件大小和修改时间冒充完整内容一致性。

还需定义日志与临时文件保留、磁盘空间预算、后台任务状态、断线恢复、结果取回范围和有限重试。长任务失联后先查状态，禁止直接重复启动。正式执行始终需要最终人工确认，本轮没有启动授权。

## 6. 下一步准备顺序

1. 确认6行样本是否为独立生物学重复，提供批次/配对信息；确认比较方向。
2. 提供实际 FASTQ 文件清单和建库链特异性，确定 Tab 或逗号文件规范。
3. 提供准确参考路径和 fastp wrapper/config，补齐项目配置；未知项不猜填。
4. 确认过滤、设计、FDR/FC 和富集方案，写入 analysis_plan.md。
5. 实现配置 schema、加载与本地预检查，验证样本错配、缺文件、占位值和模式 C 禁跑规则；先输出计划。
6. 用户准备 Pod 后核查环境、共享存储、权限和资源，再做独立小规模验证。
7. 准备项全部通过且用户明确确认后，创建独立正式 run 并启动分析。

目前准备核查仅覆盖本地文本和基础元数据一致性，尚未证明输入数据、参考、统计设计和计算环境可用于正式分析。
