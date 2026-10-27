# 项目冻结运行包

通用源码版本为Git标签v1.0.0。当前项目验证成功由用户确认，实际运行编号为v1_test6_20261027_retry01。

| 包 | 状态 | 压缩包SHA256 |
|---|---|---|
| v1_test6_20261027_retry01 | 当前6样本运行；Shell验收通过，R已投递，用户确认流程验证成功 | 4103ab2e605749370db077698092212dc9e38c0d2d3d36418d21bcc047a4333c |
| v1_test6_20261027_release | 首次50GiB容器正式Shell运行失败；保留追溯，不应重复启动 | f1e763ca0b505edab72835f38bd2b9c1b2c0abb51e85a5f7880984b57555d90b |

包目录、tar.gz和sha256文件均保持原样。包内说明是构建时快照；retry01包曾注明仅授权Shell，此后用户另行授权R，进展见项目计划及logs，不改旧快照。

旧r1/r2/r3和prepared已移出工作区，可从Git标签baseline-before-v1-cleanup恢复。删除文件及指纹见docs/v1_cleanup_inventory.json。

服务器代码：/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_retry01。

服务器结果：/home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_retry01。

包已有结果，不要重复启动入口。新分析请生成新run_id，不覆盖现有目录。
