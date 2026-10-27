# 6样本Shell重新投递记录

- 用户明确授权更新Pod后的全新Shell运行（fastp、STAR、featureCounts、MultiQC），启动确认后停止持续监控；暂不启动R。
- run_id：v1_test6_20261027_retry01；项目配置ID：xiehe_zhouyisheng_20261018。
- 启动时间：2026-10-27 17:51:51（北京时间）。
- context：zhangke@med.thu；namespace：renkelab-zhangke。
- Shell Pod：zk2-med-6dc5cbcb5d-wd5lj；container：zk260818-container。
- 执行账号zhangke，UID1482；后台主进程PID2174；启动检查发现fastp子进程PID2299。
- Pod限制：CPU64、内存300GiB；容器实际memory.limit_in_bytes=322122547200；配置工具线程12，BAM排序内存4GiB（不代表整个STAR进程内存限制）。
- 包目录：/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_retry01。
- 输出根目录：/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_retry01。
- 包SHA256：4103ab2e605749370db077698092212dc9e38c0d2d3d36418d21bcc047a4333c。
- 与已验收包比较，通用源码和样本/比较表未变，完整配置仅kubernetes.shell_pod改变。保留旧失败运行，从全部6样本fastp开始，不复用部分结果。
- 新Pod身份、存储、配置指纹、参考及输入和工具检查通过；版本fastp0.21.0、STAR2.7.11b、featureCounts2.0.6、samtools1.21、MultiQC1.30。samtools仍有原环境ncurses版本信息提示，未升级环境。
- 启动后单次确认：status=running，主进程及fastp子进程均以UID1482运行；R未启动。详见startup_check.json。

本次仅确认启动，不代表分析完成；没有持续监控或自动完成后回调机制。依用户要求结束对话，后续按需检查完成状态及验收结果。Shell成功后也不会自动启动R。
