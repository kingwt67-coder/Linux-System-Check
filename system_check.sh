#!/bin/bash
#===================================================================
#  系统巡检脚本 - System Inspection Script
#  版本: 1.0
#  用法: bash system_check.sh
#  适用: Rocky Linux 9 / CentOS 7+
#===================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SEP="==================================================================="

#------------- 辅助函数 -------------
print_title() {
    echo -e "${BLUE}${SEP}${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}${SEP}${NC}"
}

print_info() {
    printf "  %-20s : %s\n" "$1" "$2"
}

print_alert() {
    echo -e "  ${RED}⚠ $1${NC}"
}

check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $service - 运行中"
    else
        echo -e "  ${RED}✗${NC} $service - 未运行"
    fi
}

#------------- 1. 主机信息 -------------
print_title "主机基本信息"
print_info "主机名"       "$(hostname)"
print_info "系统版本"     "$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
print_info "内核版本"     "$(uname -r)"
print_info "运行时间"     "$(uptime -p | sed 's/up //')"
print_info "启动时间"     "$(who -b | awk '{print $3, $4}')"
print_info "当前在线用户" "$(who | wc -l) 人"
echo ""

#------------- 2. CPU 与系统负载 -------------
print_title "CPU 与系统负载"
cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
cpu_cores=$(nproc)
print_info "CPU 型号"   "$cpu_model"
print_info "CPU 核心数" "$cpu_cores"

load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
load_5min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $2}' | xargs)
load_15min=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $3}' | xargs)
print_info "负载 (1/5/15分钟)" "${load_1min} / ${load_5min} / ${load_15min}"

load_int=${load_1min%.*}
if [[ $load_int -gt $cpu_cores ]]; then
    print_alert "CPU 负载过高！1 分钟负载 ($load_1min) 超过核心数 ($cpu_cores)"
fi
echo ""

#------------- 3. 内存 -------------
print_title "内存使用情况"
mem_total=$(free -m | awk 'NR==2{print $2}')
mem_used=$(free -m | awk 'NR==2{print $3}')
mem_available=$(free -m | awk 'NR==2{print $7}')
mem_usage=$((mem_used * 100 / mem_total))

print_info "总内存"     "${mem_total} MB"
print_info "已用内存"   "${mem_used} MB"
print_info "可用内存"   "${mem_available} MB"
print_info "使用率"     "${mem_usage}%"

if [[ $mem_usage -gt 90 ]]; then
    print_alert "内存使用率过高: ${mem_usage}%! "
elif [[ $mem_usage -gt 70 ]]; then
    echo -e "  ${YELLOW}⚠ 内存使用率偏高: ${mem_usage}%${NC}"
fi

swap_total=$(free -m | awk 'NR==3{print $2}')
swap_used=$(free -m | awk 'NR==3{print $3}')
if [[ $swap_total -gt 0 ]]; then
    swap_usage=$((swap_used * 100 / swap_total))
    print_info "Swap 使用率" "${swap_usage}%"
    if [[ $swap_usage -gt 50 ]]; then
        print_alert "Swap 使用率过高: ${swap_usage}%! 可能存在内存泄漏"
    fi
fi
echo ""

#------------- 4. 磁盘 -------------
print_title "磁盘使用情况"
df -h | grep -vE '^Filesystem|tmpfs|devtmpfs|cdrom' | while read -r line; do
    filesystem=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    mount=$(echo "$line" | awk '{print $6}')

    printf "  %-25s %-10s %-10s %-10s\n" "$mount" "$size" "$used" "$avail"

    if [[ $usage -gt 90 ]]; then
        echo -e "  ${RED}${usage}%${NC}"
        print_alert "分区 $mount 使用率 ${usage}%, 即将耗尽！"
    elif [[ $usage -gt 80 ]]; then
        echo -e "  ${YELLOW}${usage}%${NC}"
    else
        echo -e "  ${GREEN}${usage}%${NC}"
    fi
done
echo ""

print_info "inode 检查" ""
df -i / | awk 'NR==2{printf "  根分区 inode: 已用 %s / 共 %s (%s)\n", $3, $2, $5}'
echo ""

#------------- 5. 进程 TOP 5 -------------
print_title "CPU 占用 TOP 5 进程"
echo ""
ps aux --sort=-%cpu | head -6 | awk 'NR==1{printf "  %-8s %-6s %-6s %-10s %s\n", "USER","PID","CPU%","MEM%","COMMAND"} NR>1{printf "  %-8s %-6s %-6s %-10s %s\n", $1,$2,$3,$4,$11}'
echo ""

print_title "内存占用 TOP 5 进程"
echo ""
ps aux --sort=-%mem | head -6 | awk 'NR==1{printf "  %-8s %-6s %-6s %-10s %s\n", "USER","PID","CPU%","MEM%","COMMAND"} NR>1{printf "  %-8s %-6s %-6s %-10s %s\n", $1,$2,$3,$4,$11}'
echo ""

#------------- 6. 网络连接 -------------
print_title "网络连接统计"
echo ""
echo "  连接状态分布："
ss -tna | awk 'NR>1{state[$1]++} END{for(s in state) printf "    %-15s : %d\n", s, state[s]}' | sort
echo ""

print_info "监听端口" ""
ss -tlnp 2>/dev/null | awk 'NR>1{printf "  %-22s %s\n", $4, $NF}' | head -10
echo ""

#------------- 7. 登录用户与记录 -------------
print_title "登录用户"
echo ""
who | awk '{printf "  %-12s %-10s %-16s %s\n", $1, $2, $3, $5}'
echo ""

print_title "最近登录记录"
echo ""
last -n 5 | awk '{printf "  %-12s %-10s %-16s %s %s\n", $1, $2, $3, $4, $5}'
echo ""

#------------- 8. 关键服务 -------------
print_title "关键服务状态"
check_service "sshd"
check_service "crond"

if systemctl is-active --quiet firewalld 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} firewalld - 运行中"
fi

selinux_status=$(getenforce 2>/dev/null)
if [[ -n $selinux_status ]]; then
    print_info "SELinux 状态" "$selinux_status"
fi
echo ""

#------------- 9. 汇总 -------------
print_title "巡检完成"
echo ""
echo "  巡检时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  脚本版本: 1.0"
echo ""

warnings=0
[[ -n $load_int && $load_int -gt $cpu_cores ]] && ((warnings++))
[[ -n $mem_usage && $mem_usage -gt 90 ]] && ((warnings++))
[[ -n $swap_usage && $swap_usage -gt 50 ]] && ((warnings++))

if [[ $warnings -gt 0 ]]; then
    echo -e "  ${RED}⚠ 发现 ${warnings} 项告警，请及时处理！${NC}"
else
    echo -e "  ${GREEN}✓ 系统运行正常，未发现异常。${NC}"
fi

echo ""
echo -e "${BLUE}${SEP}${NC}"
