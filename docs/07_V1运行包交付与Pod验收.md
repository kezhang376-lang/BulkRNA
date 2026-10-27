# BulkRNA V1 运行包交付与 Pod 验收

日期：2026-10-27。项目：20261018_xiehe_zhou，两组6样本。本次交付可整体拷贝的项目专属代码包，并完成Pod中的小规模兼容性测试；**未启动完整6样本分析**。

## 1. 唯一推荐使用的交付包

- 本地目录：`projects/20261018_xiehe_zhou/releases/v1_test6_20261027_release/`
- 本地压缩包：`projects/20261018_xiehe_zhou/releases/v1_test6_20261027_release.tar.gz`
- 压缩包大小：36,128字节；内容31个文件。
- SHA256：`f1e763ca0b505edab72835f38bd2b9c1b2c0abb51e85a5f7880984b57555d90b`
- 同包中文说明：`README_V1_CN.md`；英文简明入口说明：`README_RUN.md`。

服务器已上传并核验的目录：

```text
/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release
```

两个Pod共享此目录。拷贝时必须保留整个目录的结构，不能仅拷贝单个R文件。包内使用runtime.json固定输入、参考和结果路径，适用于当前已核验的Pod环境；迁到其他环境需要重新配置与验收。

早期review_v1、review_v2、test_6samples_review_20261027和构建/诊断候选r1/r2/r3均非本次最终交付。其中r2用于暴露新版GSEA接口问题，r3构建未完成。保留它们用于追溯，不应启动这些旧包。

## 2. 具体入口和预期结果

| 文件 | 所在Pod | 行为 |
|---|---|---|
| run_shell.sh | Shell | 默认check-only；显式--execute时前台运行完整Shell阶段 |
| run_R.sh | R | 默认environment-only；--check-only校验Shell成功后的counts；--execute前台执行R分析 |
| start_shell.sh | Shell | 仅接受显式--execute，先预检，再后台启动，写锁/PID/日志 |
| start_R.sh | R | 同上，但强制要求Shell已成功且counts验收通过 |

全部入口核对SHA256清单，校验zhangke的非root身份；不自动切换账号、不创建/删除Pod、不覆盖已有结果、不实现断点复用。后台返回`launched_not_completed`不代表成功；完成情况以阶段status.json和验收为准。

完整6样本结果将写入：

```text
/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_release/
  launcher/                 # 后台启动PID、锁和日志
  shell/
    clean/                  # clean FASTQ
    bam/                    # 排序BAM、index、STAR相关产物
    counts/raw_counts.tsv   # 唯一稳定基因ID × 明确样本ID
    qc/                     # fastp/STAR/分配率/MultiQC
    logs/
    status.json
  analysis/
    qc/                     # 表达分布、PCA、相关性、聚类
    de/                     # 完整基因表、显著表、dds、MA/火山图
    enrichment/             # GO ORA/GSEA与映射/排序/后端诊断
    report.html             # 可浏览的汇总及结果索引
    analysis.log
    sessionInfo_start.txt
    sessionInfo_end.txt
    status.json
```

本次最终只读复核确认上述**完整结果根目录尚不存在**。已有validation目录中的文件是兼容性测试产物，不可当作真实6样本结果。

## 3. 本次新增的可部署能力

- 代码、配置、CSV/TSV、分析计划、说明和验证脚本冻结成独立包，SHA256清单在每次入口启动前核对。
- Shell显式配置`/miniconda3/bin`，不依赖交互式登录环境；旧fastp仍严格使用配置文件指定的0.21.0。
- R明确使用R Pod的`/usr/bin/Rscript`，防止误用Shell Pod的Conda R。
- STAR增加4GiB排序内存上限。YAML使用4294967296.0以避免R YAML的32位整数溢出，JSON保留精度，传给STAR时转为整数。这是执行资源设置，不改变统计阈值或比对科学参数。
- 基本后台启动保护：分离会话、独占启动锁、PID/时间/日志；不等同于队列系统、恢复或Pod重启后的任务续跑。
- R入口在FASTQ模式下强制等待Shell成功；新增report.html汇总。
- 上传器仅以指定账号向全新的项目workflow目录解压小代码包，验证压缩包和文件哈希，不覆盖旧目录、不处理原始大数据。

## 4. Pod实际验证

全程通过用户指定账号zhangke（UID1482）操作。context=`zhangke@med.thu`，namespace=`renkelab-zhangke`。

| 检查 | 结果 |
|---|---|
| 最终包本地schema、CSV、比较、SHA256 | 通过，0个本地阻断项 |
| 最终包两Pod可见性与身份 | 通过 |
| 最终包Shell预检 | 通过：当前6样本输入和参考、工具、fastp0.21.0 |
| R环境检查 | 实际加载DESeq2/edgeR/clusterProfiler/OrgDb等依赖通过 |
| Bash -n | run_shell/run_R/start_shell/start_R全部通过 |
| Python AST | 三个运行器通过 |
| 包未被修改 | 服务器最终SHA256清单无不匹配文件 |
| 本地Python单元测试 | 11项通过，含包校验、账号、旧fastp、环境、后台锁和解析 |

### Shell工具链实际小测

使用10GY5FFRT-1前10,000对reads，完整跑通旧fastp、现有STAR索引、samtools检查/建索引、featureCounts和MultiQC。原始FASTQ只读，截取数据与输出在独立validation目录。

- fastp：0.21.0，配置SHA256=`fe736fbeba3e34117cafd0e0bae9ac83648bd5ed4775fb4fe8633976448ddb7c`。
- STAR：2.7.11b；现有GRCm39 index实际加载和比对通过。
- featureCounts：2.0.6；明确-p/--countReadPairs。
- samtools：1.21；MultiQC：1.30。
- 10,000对输入，经fastp后9,976对，STAR unique为9,044对（90.66%）；仅用来证明该探针正常运行，不外推完整文库质量。
- featureCounts的summary单位与STAR input pairs不必完全相等，本次保留原报告和通用processed_units字段，不为对齐数字擅自更改多重比对策略。

实际测试位置为`validation/v1_test6_20261027_r2/shell_smoke/`。最终包与该测试包的shell_stage.py字节完全相同、完整config对象相同；最终包又通过其自身入口预检，因而未重复做同一小样本比对。

### R完整入口和阳性绘图小测

最终包R测试位于`validation/v1_test6_20261027_release/`：

- `r_smoke/`：1,200个已知Ensembl基因ID的人工counts，6列沿用真实样本/分组标签；实际运行最终R入口，QC、配置过滤、DESeq2、GO ORA/GSEA、PDF、模型、日志及report.html全部完成。人工值不提供真实科研结论。
- `go_positive/`：人为构造某GO集合的阳性排序，显著GSEA气泡图、ORA气泡图和指定GO曲线全部生成。验证曲线用GO:0000122仅为测试标识，不表示它在真实样本中显著。
- R4.6.0、DESeq2 1.52.0、clusterProfiler 4.20.0、enrichplot 1.32.0、fgsea 1.38.0、org.Mm.eg.db 3.23.0等已在实际Pod中使用，而非仅检查目录存在。

## 5. 核验中发现并修复的真实兼容性问题

clusterProfiler4.20.0中的gseGO更换了后端包装，旧版传入的by/eps/BPPARAM等参数会被忽略；诊断候选包即使退出0，仍产生异常GO标识警告、无法稳定绘制目标曲线。因此没有把该候选当作验收通过。

最终实现直接使用已安装的`fgsea::fgseaMultilevel`，基因集由相同OrgDb的GOALL与GO.db构建，按排名基因交集计算集合大小。保留用户的log2FC排序、GO范围3–800、BH、seed20261027、eps1e-10；标准双向score、exponent1、nPermSimple1000/sampleSize101与原fgsea包装器默认方法一致。标准gseaResult容器只承担保存和绘图，不再决定实际统计后端。

完整表直接导出result槽，保留有效GO ID和NA统计状态，防止新版accessor筛选制造NA行。实际后端和版本写入go_gsea_backend.json，后续不依赖“函数名字没变”来判断方法一致。

最终人工全流程测试无上述警告；人工阳性集合出现部分p值低于eps的精度下界提示，本次保留eps并记录，未自动调阈值、换方法或提高显著性。samtools环境仍有ncurses库版本信息提示，但本次BAM检查和索引实际成功，没有擅自升级系统库。

## 6. 方法和能力边界

V1覆盖本轮启用的标准模块和基本独立启动/日志/结果保护。用户设置的~group、Wald、FDR0.05、abs(log2FC)>1、75%非零过滤（6样本至少4个非零）保持不变；组特异基因可能被该过滤去除，仍需在解释结果时保留此限制。

兼容性小测不能证明完整文库的QC、真实数据的模型假设或内存峰值已通过。完整6样本运行中如parametric拟合不适用、输入异常、资源不足或某模块失败，仍应停止并报告，不能为了成功改模型、阈值或删除样本。

未实现内容保持明确：KEGG、七组LRT/WGCNA、模式B/C自动调度、按指纹恢复、完整队列调度及Pod重建后恢复。不得把本轮V1交付描述为全部研究内容已完成。

## 7. 本地验收证据与下一步

- 最终审计JSON：`logs/v1_test6_20261027_release/pod_compatibility_audit.json`。
- 初始Shell/诊断审计：`logs/v1_test6_20261027_r2/pod_compatibility_audit.json`。
- 中文操作说明：`projects/20261018_xiehe_zhou/运行说明_V1.md`，同内容已放入最终包README_V1_CN.md。

下一步为复核最终执行计划后，明确启动本次完整6样本测试。使用最终包start_shell.sh，再在Shell成功、counts验收后启动start_R.sh；本次没有调用这两个启动命令。
