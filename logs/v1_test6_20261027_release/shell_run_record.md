# 6 样本 Shell 正式运行记录

- 用户授权：启动项目 20261018_xiehe_zhou 的 6 样本 Shell 阶段，完成 fastp、STAR、featureCounts、MultiQC，并验收；暂不启动 R。
- 项目配置 ID：xiehe_zhouyisheng_20261018。
- run_id：v1_test6_20261027_release。
- 启动时间：2026-10-27 08:52:46 UTC（北京时间 16:52:46）。
- Shell Pod：zk1-med-6ff4f46898-rlbtd；容器 zk250904-container。
- context：zhangke@med.thu；namespace：renkelab-zhangke。
- 执行账号：zhangke，UID 1482；后台主进程 PID 14702。
- 包位置：/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release。
- 结果根目录：/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_release。
- 样本：10GY5FFRT-1/2/3、control-1/2/3；逐样本 fastp → STAR → samtools 检查/索引，再汇总 featureCounts 和 MultiQC。
- 资源：fastp/STAR/排序/featureCounts 各 12 线程；STAR BAM 排序上限 4 GiB；Pod 内存限额 50 GiB。
- 配置、样本、比较文件 SHA256 与冻结包原始快照完全一致；入口 SHA256/账号/工具/输入检查通过。
- fastp 参数文件 SHA256：fe736fbeba3e34117cafd0e0bae9ac83648bd5ed4775fb4fe8633976448ddb7c。
- 12 个 FASTQ 总体积约 24.5 GB；存储可用约 20 TB（共享文件系统总体容量，不代表个人配额）。
- 创建缺失的 results/runs 父目录时使用 zhangke；启动前该 run_id 结果目录不存在。
- 未变更科学参数、样本、软件环境或 Pod 配置；未启动 R。

启动状态是 launched_not_completed，不代表分析成功。持续只读观察见 shell_observations.jsonl；最近状态见 shell_observation.latest.json。最终状态与产物需单独验收。

用户随后要求结束本地监控，让已启动程序继续在服务器运行，按需再查询。已停止本地只读观察器，不停止/重启服务器Shell，不启动R。最近观察为首样本fastp完成、STAR正在比对；整批状态尚未验收。

2026-10-27约17:41按用户要求检查：Shell于17:17:43 failed，第二个样本STAR退出137；前两样本fastp、首样本STAR/BAM索引完成。内存峰值达50GiB上限且有累计OOM kill。完整证据见shell_status_check_20261027.md。未重启，R未启动。
