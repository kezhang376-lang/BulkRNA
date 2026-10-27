# 项目运行包

当前唯一推荐版本：**v1_test6_20261027_release**。

- `v1_test6_20261027_release/`：整体可拷贝目录。
- `v1_test6_20261027_release.tar.gz`：整体可拷贝压缩包。
- `.tar.gz.sha256`：压缩包SHA256。
- `v1_test6_20261027_release.validation.json`：本次Pod兼容性审计副本。
- 包内`README_V1_CN.md`：中文运行说明。

旧r1/r2/r3为构建或诊断记录，不应启动。完整6样本分析没有因生成/上传/核验运行包而自动开始。

最终包已部署到 `/home/zhangke/RNA-seq/20261027_xiehe_zhou/workflow/v1_test6_20261027_release`，SHA256为 `f1e763ca0b505edab72835f38bd2b9c1b2c0abb51e85a5f7880984b57555d90b`。更多证据见仓库docs/07_V1运行包交付与Pod验收.md。

## 最新已投递运行：v1_test6_20261027_retry01

上文release包对应的首次正式Shell运行已失败（第二样本STAR退出137，50GiB容器内存压力），不再作为当前运行。用户更换300GiB Shell Pod后，已生成并上传v1_test6_20261027_retry01包，于2026-10-27北京时间17:51:51启动Shell，PID2174，单次核验running。新包SHA256：4103ab2e605749370db077698092212dc9e38c0d2d3d36418d21bcc047a4333c。新包只更新Shell Pod，分析参数、样本和源码保持一致；R未启动，未持续监控，结果尚未验收。旧包及失败结果继续保留作追溯；不要重新启动旧包。
