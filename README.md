Linux-System-Check
一个自动化的企业级 Linux 系统巡检工具。支持监控 CPU、内存、磁盘、网络和核心进程，并配置了自动化的日志轮转清理机制。

🚀 核心功能
全方位监控：一键抓取系统负载、内存使用率、磁盘空间、Top 进程及网络连接状态。

自动化运行：完美适配 crontab，支持后台静默巡检与异常留痕。

日志合规管理：内置 logrotate 配置规则，自动切割并压缩历史日志，杜绝磁盘爆满风险。

🛠️ 快速部署与使用指南
以下是将本脚本部署为企业级自动化巡检任务的完整步骤。

1. 部署脚本与初始化权限
Bash
# 将脚本移动到企业常用的运维目录
mv system_check.sh /root/

# 赋予脚本执行权限
chmod +x /root/system_check.sh
2. 配置日志轮转规则
为了防止长期运行导致日志文件撑爆磁盘，使用 logrotate 配置自动清理策略。

Bash
# 创建并编辑日志轮转配置文件
cat << 'EOF' > /etc/logrotate.d/system_check
/var/log/system_check.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF
说明：上述配置每天切割一次日志，保留最近 7 天的历史记录并压缩。

3. 配置定时任务
使用 cron 设置每天定时执行脚本，并自动追加日志。

Bash
# 执行 crontab -e 编辑定时任务，然后将以下行添加到文件末尾：
0 2 * * * /bin/bash /root/system_check.sh >> /var/log/system_check.log 2>&1
说明：此配置使脚本在每天凌晨 2 点执行，记录所有的标准输出和错误信息。
