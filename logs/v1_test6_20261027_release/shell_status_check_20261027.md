# Shell 运行状态检查

检查时间：2026-10-27 北京时间约17:41；只读远程检查，未重启或修改任务。

运行 v1_test6_20261027_release 已失败，于北京时间17:17:43记录failed。主进程PID14702已成为僵尸进程（Z），不再计算。

| 样本 | fastp | STAR及排序BAM |
|---|---|---|
| 10GY5FFRT-1 | 完成 | 完成，存在BAM及BAI；启动流程已执行quickcheck和index |
| 10GY5FFRT-2 | 完成 | 失败，STAR被Killed，退出137，排序BAM为0字节 |
| 10GY5FFRT-3 | 未执行 | 未执行 |
| control-1 | 未执行 | 未执行 |
| control-2 | 未执行 | 未执行 |
| control-3 | 未执行 | 未执行 |

本运行的featureCounts、MultiQC未执行，尚无完整6样本计数矩阵；R未启动。Pod为Running且重启次数0，不代表后台分析仍在运行。Pod中其他用户会话下的工具进程不属于本次工作流，不据此判断本流程完成。

内存诊断：容器限额53687091200字节（50GiB），历史峰值53694537728字节；memory.failcnt=772，memory.oom_control显示oom_kill=2。结合STAR被Killed/137，强烈支持内存耗尽导致终止，但计数为容器累计值，缺乏该时点内核OOM明细，无法仅凭此确定每次OOM的时间和被杀进程。4GiB配置只约束STAR BAM排序内存，不是STAR全部内存或整个Pod的总内存上限。

原始数据、冻结包及部分产物保留。未修改Pod资源、分析参数、状态文件或锁，未自动重跑，未启动R。后续应先制定内存与新运行/已完成产物复用方案；V1没有自动断点恢复。

原始证据：shell_observation.latest.json、shell_failure_diagnostics.json。
