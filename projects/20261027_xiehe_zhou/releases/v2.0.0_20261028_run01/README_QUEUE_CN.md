# 本次Shell与R衔接

用户于2026-10-28授权两个阶段，启动后不需本地持续监控。

Shell Pod启动：bash start_shell.sh --execute。
R Pod投递等待任务：bash start_R_after_shell.sh --execute。

两个入口均须先切换zhangke账号，不能以root计算。R等待任务只在共享路径中Shell succeeded、样本/计数/BAM索引/MultiQC依赖检查和R输入模型检查通过后调用start_R.sh。最多等待48小时；Shell失败、检查失败或超时则停止且记录失败，不重试，不重跑，不修改参数。

launcher/r.queue.launch.json记录等待进程PID，r.queue.status.json记录waiting_for_shell或r_launched_not_completed/failed，r.queue.log保存日志，r.dependency_audit.json保存衔接验收。等待进程退出后R后台计算继续；最终分析状态以gene_expr_data/status.json为准。

不要再手动重复调用start_R.sh或等待入口。关闭本地Codex不影响这两个服务器后台任务；Pod重启/驱逐仍可能中断，脚本不自动恢复。此功能为本项目附加脚本，不表示通用调度器和断点恢复已实现。
