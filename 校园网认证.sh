#!/usr/bin/env bash
#==========================================================
#  校园网 quickauth 自动认证脚本（Termux 兼容版）
#  支持多账号（兼容 mksh，不用数组）
#  需要 Root 权限运行
#==========================================================

# ----------------- Root 权限检查 -----------------
if [ "$(id -u 2>/dev/null)" != "0" ]; then
    echo "========================================"
    echo "           需要 Root 权限"
    echo "========================================"
    echo
    echo "本脚本必须以 Root 权限运行。"
    echo "请使用以下方式之一启动："
    echo
    echo "  1) su 后再执行脚本"
    echo "  2) 在 MT 管理器中以 Root 身份执行"
    echo "  3) su -c \"bash 脚本路径\""
    echo
    echo "当前用户 UID: $(id -u 2>/dev/null)"
    echo
    echo -n "按回车退出..."
    read _
    exit 1
fi

# ----------------- 配置文件路径 -----------------
CONF_FILE="/storage/emulated/0/Android/D1145C"

# ----------------- 颜色定义 -----------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- 清屏函数（兼容 mksh / termux） ----------
clear_screen() {
    if command -v tput >/dev/null 2>&1; then
        tput reset 2>/dev/null || printf '\033[2J\033[3J\033[H'
    else
        printf '\033[2J\033[3J\033[H'
    fi
}

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

# ---------- 开屏公告 ----------
show_notice() {
    clear_screen
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

# ---------- 多账号工具函数 ----------

count_accounts() {
    [ -f "$CONF_FILE" ] || { echo 0; return; }
    local n
    n=$(grep -c '^USERID=' "$CONF_FILE" 2>/dev/null)
    [ -z "$n" ] && n=0
    echo "$n"
}

list_accounts() {
    grep '^USERID=' "$CONF_FILE" 2>/dev/null | sed 's/^USERID=//; s/^"//; s/"$//' | awk '{printf "  %d) %s\n", NR, $0}'
}

get_account() {
    local n="$1"
    local line_user line_pass
    line_user=$(grep '^USERID=' "$CONF_FILE" 2>/dev/null | sed -n "${n}p" | sed 's/^USERID=//; s/^"//; s/"$//')
    line_pass=$(grep '^PASSWD=' "$CONF_FILE" 2>/dev/null | sed -n "${n}p" | sed 's/^PASSWD=//; s/^"//; s/"$//')
    echo "$line_user|$line_pass"
}

# 校验账号：必须 11 位纯数字
is_valid_userid() {
    case "$1" in
        *[!0-9]*) return 1 ;;
    esac
    [ ${#1} -eq 11 ] || return 1
    return 0
}

add_account() {
    clear_screen
    echo "========================================"
    echo "              添加新账号"
    echo "========================================"
    local new_user="" new_pass=""
    while true; do
        echo -n "请输入账号（userid）: "
        read new_user
        new_user=$(echo "$new_user" | tr -d '\r\n ')
        if [ -z "$new_user" ]; then
            echo -e "${RED}账号不能为空，请重新输入。${NC}"
            continue
        fi
        if ! is_valid_userid "$new_user"; then
            echo -e "${RED}账号必须为 11 位纯数字，请重新输入。${NC}"
            continue
        fi
        break
    done

    while [ -z "$new_pass" ]; do
        echo -n "请输入密码（passwd）: "
        read new_pass
        new_pass=$(echo "$new_pass" | tr -d '\r\n ')
        [ -z "$new_pass" ] && echo "密码不能为空，请重新输入。"
    done

    if grep -q "^USERID=\"${new_user}\"$" "$CONF_FILE" 2>/dev/null; then
        local line_num
        line_num=$(grep -n "^USERID=\"${new_user}\"$" "$CONF_FILE" | head -1 | cut -d: -f1)
        local pass_line=$((line_num+1))
        sed -i "${pass_line}s|.*|PASSWD=\"${new_pass}\"|" "$CONF_FILE"
        echo -e "${YELLOW}该账号已存在，密码已更新。${NC}"
    else
        {
            echo "USERID=\"${new_user}\""
            echo "PASSWD=\"${new_pass}\""
        } >> "$CONF_FILE"
        echo -e "${GREEN}账号已添加。${NC}"
    fi

    chmod 600 "$CONF_FILE" 2>/dev/null
    echo "当前共 $(count_accounts) 个账号。"
    sleep 1
}

delete_account() {
    clear_screen
    local total
    total=$(count_accounts)
    if [ "$total" -eq 0 ]; then
        echo "当前没有任何账号。"
        sleep 1
        return
    fi

    echo "========================================"
    echo "              删除账号"
    echo "========================================"
    list_accounts
    echo "  0) 取消"
    echo "========================================"
    echo -n "请选择要删除的账号: "
    read del_idx
    del_idx=$(echo "$del_idx" | tr -d '\r\n ')

    case "$del_idx" in
        0|"") echo "已取消。"; sleep 1; return ;;
    esac

    if [ "$del_idx" -ge 1 ] 2>/dev/null && [ "$del_idx" -le "$total" ]; then
        local u_line p_line
        u_line=$(grep -n '^USERID=' "$CONF_FILE" | sed -n "${del_idx}p" | cut -d: -f1)
        p_line=$((u_line+1))
        sed -i "${p_line}d" "$CONF_FILE"
        sed -i "${u_line}d" "$CONF_FILE"
        echo -e "${GREEN}已删除。${NC}"
    else
        echo -e "${RED}输入无效。${NC}"
    fi
    sleep 1
}

# 依次尝试所有账号
try_all_accounts() {
    clear_screen
    local total
    total=$(count_accounts)
    if [ "$total" -eq 0 ]; then
        echo "当前没有任何账号。"
        sleep 1
        return 1
    fi

    echo "========================================"
    echo "         依次尝试所有账号认证"
    echo "========================================"
    echo

    local i=1
    while [ "$i" -le "$total" ]; do
        local info u p
        info=$(get_account "$i")
        u=$(echo "$info" | cut -d'|' -f1)
        p=$(echo "$info" | cut -d'|' -f2)

        USERID="$u"
        PASSWD="$p"

        echo -e "${CYAN}---- 第 $i/$total 个账号: $u ----${NC}"
        if do_auth; then
            echo
            echo -e "${GREEN}==> 账号 $u 认证成功，停止尝试。${NC}"
            echo
            echo -n "按回车返回主菜单..."
            read _
            return 0
        fi
        echo
        i=$((i+1))
    done

    echo -e "${RED}==> 全部账号均未认证成功。${NC}"
    echo
    echo -n "按回车返回主菜单..."
    read _
    return 1
}

load_or_init_conf() {
    clear_screen

    if [ "$(count_accounts)" -eq 0 ]; then
        echo "========================================"
        echo "        首次使用，请设置第一个账号"
        echo "========================================"
        add_account
    fi

    while true; do
        clear_screen
        local total
        total=$(count_accounts)
        echo "========================================"
        echo "              选择账号"
        echo "========================================"
        list_accounts
        echo "  a) 添加新账号"
        echo "  d) 删除账号"
        echo "  e) 全部账号依次尝试"
        echo "  0) 退出"
        echo "========================================"
        echo -n "请选择: "
        read sel
        sel=$(echo "$sel" | tr -d '\r\n ')

        case "$sel" in
            a|A) add_account; continue ;;
            d|D) delete_account; continue ;;
            e|E)
                if try_all_accounts; then
                    return 0
                else
                    continue
                fi
                ;;
            0)  echo "已退出。"; exit 0 ;;
        esac

        if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le "$total" ]; then
            local info
            info=$(get_account "$sel")
            USERID=$(echo "$info" | cut -d'|' -f1)
            PASSWD=$(echo "$info" | cut -d'|' -f2)
            echo
            echo -e "${GREEN}已选择账号: ${USERID}${NC}"
            sleep 1
            return 0
        fi

        echo -e "${RED}输入无效，请重新选择。${NC}"
        sleep 1
    done
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
    clear_screen
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
    clear_screen
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
        clear_screen
        echo "========================================"
        echo "        校园网快捷认证脚本"
        echo "        作者: 忘念"
        echo "        账号: ${USERID}"
        echo "========================================"
        echo "  1) 后台无限访问"
        echo "  2) 单次访问"
        echo "  3) 切换账号"
        echo "  0) 退出"
        echo "========================================"
        echo -n "请选择 [0-3]: "
        read choice
        choice=$(echo "$choice" | tr -d '\r\n ')
        case "$choice" in
            1) start_daemon ;;
            2) single_run ;;
            3) load_or_init_conf ;;
            0) echo "已退出。"; exit 0 ;;
            *) echo "无效选项，请重新输入。"; sleep 1 ;;
        esac
    done
}

# 入口
show_notice
load_or_init_conf

case "$1" in
    --daemon) run_loop ;;
    *)        show_menu ;;
esac