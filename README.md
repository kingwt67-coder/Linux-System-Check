Linux-System-Check
一个自动化的企业级 Linux 系统巡检工具。支持监控 CPU、内存、磁盘、网络和核心进程，并配置了自动化的日志轮转清理机制。

🚀 核心功能
全方位监控：一键抓取系统负载、内存使用率、磁盘空间、Top 进程及网络连接状态。

自动化运行：完美适配 crontab，支持后台静默巡检与异常留痕。

日志合规管理：内置 logrotate 配置规则，自动切割并压缩历史日志，杜绝磁盘爆满风险。

🛠️ 快速部署与使用指南
1. 部署脚本与初始化权限
将脚本移动到系统目录，并赋予执行权限。请在服务器执行以下命令：

mv system_check.sh /root/
chmod +x /root/system_check.sh

2. 配置日志轮转规则
为了防止长期运行导致日志文件撑爆磁盘，请执行以下命令创建自动清理策略：

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

3. 配置定时任务
执行 crontab -e 编辑定时任务，然后将以下行添加到文件末尾：

0 2 * * * /bin/bash /root/system_check.sh >> /var/log/system_check.log 2>&1

本项目非常适合作为 Linux 系统运维自动化的实战参考。
