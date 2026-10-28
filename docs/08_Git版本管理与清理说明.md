# Git V1基线与日常维护

本说明记录已发布的1.0.0基线，标签为v1.0.0，日常分支为main。该版本依据用户确认的验证成功状态发布；建仓未重新连接Pod或重跑分析。新目录接口2.0.0已于2026-10-28正式发布，见docs/09_新结果目录规则与修改清单.md；本文V1清单不代表新开发版的当前源码指纹。

## 三种版本标识

| 标识 | 当前值 | 用途 |
|---|---|---|
| 流程版本 | VERSION中的1.0.0及Git标签v1.0.0 | 通用源码版本 |
| 配置格式版本 | schema_version为1.0-review | 本次不更名，以免破坏加载器兼容性 |
| 实际运行编号 | v1_test6_20261027_retry01 | 项目某次冻结包、日志及输出 |

发布清单在docs/releases/v1.0.0.json，记录关键源码及对应运行包指纹。旧冻结包保持原样，不向其中补写版本字段或重新打包。

## 保存与清理

- 清理前提交及标签：baseline-before-v1-cleanup。保存清理前所有纳入Git的文件，不含下载的qc结果或原始大数据。
- 发布提交及标签：v1.0.0，包含清理后的源码、有效包及当前说明。
- 已删除：项目prepared目录、releases下r1/r2/r3目录和r2压缩包及校验文件、config.yaml.bak。该bak只与当前config的Shell Pod不同，旧值也保存在首次运行包中。
- 删除前逐文件清单、大小、SHA256在docs/v1_cleanup_inventory.json。历史说明中的旧路径可从恢复标签取回。
- 保留：原始step脚本、项目输入、backups中的原研究描述、两个实际投递包release/retry01、失败诊断、启动和Shell验收证据及测试代码。
- 项目qc是已有用户结果，全部留在磁盘并由.gitignore排除。Git不是结果备份，需另行备份它们及服务器大文件。
- skills和custom目录用.gitkeep保留；skills目前没有SKILL.md，不表示已有可调用技能。
- Git保留文件原始字节，避免换行转换破坏冻结包SHA256。
- 远程origin为https://github.com/kezhang376-lang/BulkRNA.git；按用户授权发布main和v1.0.0，不强推，不额外发布清理前恢复标签。GitHub只保存版本化文件，用户结果仍需单独备份。

## 查看与恢复

在项目根目录运行：

```powershell
git status --short
git log --oneline --decorate -5
git show v1.0.0:VERSION
git diff v1.0.0 -- scripts workflow config schemas
git show baseline-before-v1-cleanup:projects/20261018_xiehe_zhou/prepared/review_v1/review_plan.md
```

恢复指定旧文件可用git restore --source baseline-before-v1-cleanup -- <具体相对路径>。先检查工作区，避免覆盖当前修改；不要整仓恢复或hard reset。

## 后续开发

例如增加Reactome，先创建开发分支：

```powershell
git switch -c feature/reactome
```

1. 定义输入、输出、比较、基因集来源/版本、统计方法和验收标准。
2. 专属需求放projects/<项目>/custom/scripts；通用模块放scripts/R或scripts/shell，调度放workflow/orchestrator。
3. 新配置字段同步更新schema、加载器、示例和说明；仅打开开关不等于功能实现。
4. 跑本地与小数据检查；科研参数变化、远程环境变化分别记录并验证。
5. 更新VERSION和CHANGELOG，审查后提交，测试通过再合并main并发布新标签。
6. 为计算生成新的运行包和run_id，不改旧包或覆盖历史结果。

建议：兼容修复用1.0.1，新增兼容模块用1.1.0，不兼容配置/结果接口变动用2.0.0。方法或默认参数变化也必须说明科研影响。

以下命令仅在完成实际开发和审查后执行，版本号按实际调整：

```powershell
git add -- scripts workflow config schemas tests docs VERSION CHANGELOG.md
git diff --cached
git commit -m "feat: add validated Reactome analysis"
git switch main
git merge --ff-only feature/reactome
git tag -a v1.1.0 -m "BulkRNA V1.1.0"
```

不要强推、移动旧发布标签或提交认证信息。当前打包器尚未自动注入Git提交号；本次关联由外部发布清单和Git标签保存，不虚构已有接口。

## 提交身份

用户指定本仓库提交身份为kezhang376-lang <kezhang376@gmail.com>，用于正式V1提交及标签。此前清理前恢复快照使用BulkRNA Maintainer <bulkrna@localhost>，保留原历史，不重写署名。未修改全局身份或信任设置。
