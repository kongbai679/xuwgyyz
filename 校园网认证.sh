#!/usr/bin/env bash
#==========================================================
#  校园网 quickauth 自动认证脚本（Termux 兼容版）
#==========================================================

# ----------------- 配置文件路径 -----------------
CONF_FILE="/校园网网络账号密码"

if [ ! -f "$CONF_FILE" ]; then
    if ! ( : > "$CONF_FILE" ) 2>/dev/null; then
        SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
        CONF_FILE="$SCRIPT_DIR/校园网网络账号密码"
    fi
fi

# ----------------- 颜色定义 -----------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ----------------- 固定参数 -----------------
WLANACNAME="VBRAS-GXGG"
WLANACIP="10.100.100.2"
SSID=""
VLAN="20061137"
MAC="d2%3A31%3A9d%3A3a%3Ac8%3A8a"
VERSION="0"
PORTALPAGEID="13"
TIMESTAMP="1791724883761"
UUID="c91834d5-0ae7-45b7-a639-d0683168a76f"
PORTALTYPE="0"
HOSTNAME_LOCAL="LAPTOP-4C6U8OGB"
BINDCTRLID=""
VALIDATETYPE="0"
BINDOPERATORTYPE="2"

# ----------------- 可调整参数 -----------------
WLANUSERIP=""
INTERVAL=5
TIMEOUT=10
LOG_FILE="/tmp/quickauth.log"
PID_FILE="/tmp/quickauth.pid"
# ----------------------------------------------

# 依赖检查
command -v curl >/dev/null 2>&1 || { echo "缺少 curl，请先安装：pkg install curl"; exit 1; }

# ---------- 开屏公告 ----------
show_notice() {
    clear
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}              使 用 声 明${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}本程序仅供学习与技术交流使用，完全免费，不构成任${NC}"
    echo -e "${RED}何使用建议。${NC}"
    echo -e "${RED}请勿将本程序在中国大陆传播、倒卖或以任何方式用于${NC}"
    echo -e "${RED}商业用途，下载后请24小时内删除。${NC}"
    echo -e "${RED}本程序仅为逆向研究、学习成果分享${NC}"
    echo -e "${RED}安全性，使用前请自行评估风险，建议在虚拟机或测试${NC}"
    echo -e "${RED}严禁利用本程序进行违法活动，违者后果自负，作者概${NC}"
    echo -e "${RED}不负责。${NC}"
    echo -e "${RED}程序版权归属原作者，如有侵权请联系删除，将第${NC}"
    echo -e "${RED}一时间处理。${NC}"
    echo -e "${RED}========================================${NC}"
    echo
    echo -e "${CYAN}公告：${NC}"
    echo -e "${CYAN}本程序完全免费请勿外传违者后果自行承担${NC}"
    echo -e "${CYAN}本程序没有任何内部有出现一律视为圈子骗钱的${NC}"
    echo -e "${CYAN}使用前请仔细阅读使用说明，确保设置正确${NC}"
    echo -e "${CYAN}如认证失败请检查网络环境或账号密码是否正确${NC}"
    echo -e "${CYAN}本程序适用于校园网 quickauth 认证方式${NC}"
    echo -e "${CYAN}作者：${BOLD}忘念${NC}"
    echo
    echo -e "${YELLOW}我已阅读完，并认真严格执行，所有后果将自行承担${NC}"
    echo -e "${YELLOW}同意扣 1，不同意扣 0（不同意将退出程序）${NC}"
    echo -n "请输入 [1/0]: "
    while true; do
        read agree
        agree=$(echo "$agree" | tr -d '\r\n ')
        case "$agree" in
            1)
                echo -e "${GREEN}==> 已同意，即将进入主程序...${NC}"
                sleep 1
                return 0
                ;;
            0)
                echo -e "${RED}==> 您已选择不同意，程序退出。${NC}"
                exit 0
                ;;
            *)
                echo -n "输入无效，请输入 1 或 0: "
                ;;
        esac
    done
}

# ---------- 账号密码读取/保存 ----------
load_or_init_conf() {
    clear   # 独立开一个新页面
    if [ -f "$CONF_FILE" ]; then
        . "$CONF_FILE"
        if [ -n "$USERID" ] && [ -n "$PASSWD" ]; then
            echo "========================================"
            echo "        检测到已保存的账号"
            echo "========================================"
            echo "  账号: ${USERID}"
            echo "========================================"
            echo -n "是否使用之前的账号密码？[Y/n]: "
            read use_old
            use_old=$(echo "$use_old" | tr -d '\r\n ')
            case "$use_old" in
                ""|y|Y|yes|YES|Yes)
                    echo "==> 使用已保存的账号密码。"
                    sleep 1
                    return 0
                    ;;
                *)
                    echo "==> 重新输入账号密码。"
                    unset USERID PASSWD
                    sleep 1
                    ;;
            esac
        fi
    fi

    clear   # 重新开一页显示输入界面
    echo "========================================"
    echo "        首次使用，请设置账号密码"
    echo "========================================"

    while [ -z "$USERID" ]; do
        echo -n "请输入账号（userid）: "
        read USERID
        USERID=$(echo "$USERID" | tr -d '\r\n ')
        if [ -z "$USERID" ]; then
            echo "账号不能为空，请重新输入。"
        fi
    done

    while [ -z "$PASSWD" ]; do
        echo -n "请输入密码（passwd）: "
        read PASSWD
        PASSWD=$(echo "$PASSWD" | tr -d '\r\n ')
        if [ -z "$PASSWD" ]; then
            echo "密码不能为空，请重新输入。"
        fi
    done

    umask 077
    {
        echo "USERID=\"$USERID\""
        echo "PASSWD=\"$PASSWD\""
    } > "$CONF_FILE"

    if [ $? -ne 0 ]; then
        echo
        echo "警告：无法写入 $CONF_FILE"
        echo "本次账号密码仅在内存中使用，重启脚本后需要重新输入。"
        echo
        return 0
    fi

    chmod 600 "$CONF_FILE" 2>/dev/null

    echo
    echo "账号密码已保存到: $CONF_FILE"
    echo "如需修改，删除该文件后重新运行即可。"
    echo
    sleep 1
}

# 获取本机 IP
get_local_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    [ -z "$ip" ] && ip=$(ifconfig 2>/dev/null | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -v '127.0.0.1' | head -n1 | awk '{print $2}')
    [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "$ip"
}

# 拼接认证 URL
build_url() {
    local ip="$1"
    echo "http://10.100.100.1/quickauth.do?userid=${USERID}&passwd=${PASSWD}&wlanuserip=${ip}&wlanacname=${WLANACNAME}&wlanacIp=${WLANACIP}&ssid=${SSID}&vlan=${VLAN}&mac=${MAC}&version=${VERSION}&portalpageid=${PORTALPAGEID}&timestamp=${TIMESTAMP}&uuid=${UUID}&portaltype=${PORTALTYPE}&hostname=${HOSTNAME_LOCAL}&bindCtrlId=${BINDCTRLID}&validateType=${VALIDATETYPE}&bindOperatorType=${BINDOPERATORTYPE}"
}

# 执行一次认证
do_auth() {
    local ip url resp rc utf8 ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    ip="${WLANUSERIP:-$(get_local_ip)}"
    if [ -z "$ip" ]; then
        echo -e "${RED}[$ts] 认证失败：无法获取本机 IP${NC}"
        return 1
    fi

    url=$(build_url "$ip")
    resp=$(curl -s -m "$TIMEOUT" "$url" 2>/dev/null)
    rc=$?

    if [ $rc -ne 0 ]; then
        echo -e "${RED}[$ts] 认证失败：请求异常（curl 退出码 $rc），IP=$ip${NC}"
        return 1
    fi

    local ok_pat="认证成功|已通过|已认证通过|已在线|已经登录|IP 会话已认证通过"

    if printf '%s' "$resp" | grep -qE "$ok_pat"; then
        echo -e "${GREEN}[$ts] ✔ 认证成功（或已认证通过）  IP=$ip${NC}"
        return 0
    fi

    utf8=$(printf '%s' "$resp" | iconv -f GBK -t UTF-8 2>/dev/null)
    if [ -n "$utf8" ] && printf '%s' "$utf8" | grep -qE "$ok_pat"; then
        echo -e "${GREEN}[$ts] ✔ 认证成功（或已认证通过）  IP=$ip${NC}"
        return 0
    fi

    echo -e "${RED}[$ts] ✘ 认证失败  IP=$ip  返回: $(printf '%s' "$resp" | tr '\n' ' ' | head -c 300)${NC}"
    return 1
}

# 无限循环
run_loop() {
    while true; do
        do_auth
        sleep "$INTERVAL"
    done
}

# 选项 1：后台无限访问
start_daemon() {
    clear
    echo "========================================"
    echo "           后台无限访问模式"
    echo "========================================"
    echo

    if [ -f "$PID_FILE" ]; then
        oldpid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
            echo -e "${YELLOW}后台任务已在运行（PID: $oldpid）${NC}"
            echo "停止： kill $oldpid"
            echo
            echo -n "按回车返回主菜单..."
            read _
            return
        fi
    fi

    self=$(readlink -f "$0")
    : > "$LOG_FILE"
    nohup "$self" --daemon >>"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    echo -e "${GREEN}已启动后台无限访问，PID: $(cat "$PID_FILE")${NC}"
    echo "日志文件 : $LOG_FILE"
    echo "查看日志 : tail -f $LOG_FILE"
    echo "停止任务 : kill \$(cat $PID_FILE)"
    echo
    echo -n "按回车返回主菜单..."
    read _
}

# 选项 2：单次访问
single_run() {
    clear
    echo "========================================"
    echo "             单次访问模式"
    echo "========================================"
    echo
    echo "正在执行单次认证..."
    echo
    if do_auth; then
        echo
        echo -e "${GREEN}==> 访问成功${NC}"
    else
        echo
        echo -e "${RED}==> 访问不成功${NC}"
    fi
    echo
    echo -n "按回车返回主菜单..."
    read _
}

# 菜单
show_menu() {
    while true; do
        clear
        echo "========================================"
        echo "        校园网快捷认证脚本"
        echo "        作者: 忘念"
        echo "        账号: ${USERID}"
        echo "========================================"
        echo "  1) 后台无限访问"
        echo "  2) 单次访问"
        echo "  0) 退出"
        echo "========================================"
        echo -n "请选择 [0-2]: "
        read choice
        choice=$(echo "$choice" | tr -d '\r\n ')
        case "$choice" in
            1) start_daemon ;;
            2) single_run ;;
            0) echo "已退出。"; exit 0 ;;
            *) echo "无效选项，请重新输入。"; sleep 1 ;;
        esac
    done
}

# 入口
show_notice            # 先显示开屏公告并确认
load_or_init_conf      # 再读取/设置账号密码（内部会 clear 开新页）

case "$1" in
    --daemon) run_loop ;;
    *)        show_menu ;;
esac