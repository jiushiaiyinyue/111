#!/usr/bin/env bash
# linux_health_check.sh
#
# 只读的主机快速体检脚本：不安装、不修改、不删除任何东西，
# 只把可疑点打印出来，供人工判断。
#
# 用法：
#   sudo bash linux_health_check.sh            # 全部检查
#   sudo bash linux_health_check.sh cron ssh   # 只跑指定模块
#
# 模块：alias cron users ssh tmp net proc

set -u
MODULES="${*:-alias cron users ssh tmp net proc}"

hr() { printf '\n===== %s =====\n' "$1"; }
has() { case " $MODULES " in *" $1 "*) return 0;; *) return 1;; esac; }

echo "linux_health_check  $(date '+%F %T')  $(hostname)"

# ---- 1. shell 别名劫持 -------------------------------------------------
if has alias; then
  hr "alias（排查命令被重定义）"
  # 攻击者常把 ps/ss/netstat/crontab 等 alias 成空输出，隐藏痕迹
  for f in /etc/profile /etc/bash.bashrc "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    [ -f "$f" ] || continue
    grep -nE '^\s*alias\s+(ps|ss|netstat|crontab|kill|killall|pkill|find|locate|top|htop|ls)\s*=' "$f" \
      && echo "  ^^ 可疑：$f 中重定义了排查命令"
  done
  echo "-- 当前会话 --"
  alias | grep -E '^(alias )?(ps|ss|netstat|crontab|kill|killall|pkill|find|locate|top|htop|ls)=' || echo "  OK：未发现被劫持的常用命令"
fi

# ---- 2. 定时任务 ------------------------------------------------------
if has cron; then
  hr "crontab（持久化）"
  for u in $(cut -d: -f1 /etc/passwd); do
    out=$(crontab -l -u "$u" 2>/dev/null | grep -vE '^\s*#|^\s*$')
    [ -n "$out" ] && printf '[%s]\n%s\n' "$u" "$out"
  done
  for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
    [ -d "$d" ] && ls -la "$d" 2>/dev/null | grep -v '^total' | tail -n +2
  done
  echo "-- 关注点：./ 开头的隐藏文件、>/dev/null 2>&1 & disown、@reboot --"
fi

# ---- 3. 账号 ----------------------------------------------------------
if has users; then
  hr "账号（UID=0 与空密码）"
  awk -F: '$3==0 {print "  UID=0 ->", $1, $7}' /etc/passwd
  echo "-- 可登录 shell 的账号数 --"
  awk -F: '$7 !~ /(nologin|false)$/ {c++} END {print "  ", c}' /etc/passwd
  echo "-- 空密码账号 --"
  awk -F: '$2=="" {print "  ", $1}' /etc/shadow 2>/dev/null || echo "  需要 root 才能读取 /etc/shadow"
fi

# ---- 4. SSH 公钥 ------------------------------------------------------
if has ssh; then
  hr "SSH authorized_keys"
  for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    [ -f "$f" ] || continue
    printf '[%s]\n' "$f"
    awk '{print "  ", $1, substr($2,1,24)"...", $3}' "$f"
  done
  grep -nE '^PermitRootLogin|^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null
fi

# ---- 5. 常见投放目录 --------------------------------------------------
if has tmp; then
  hr "可疑目录（/tmp /var/tmp /dev/shm 下的隐藏文件）"
  find /tmp /var/tmp /dev/shm -maxdepth 2 -name '.*' -printf '  %TY-%Tm-%Td %p\n' 2>/dev/null | head -n 40
fi

# ---- 6. 网络 ----------------------------------------------------------
if has net; then
  hr "监听端口与外联"
  ss -tunlp 2>/dev/null | head -n 30
  echo "-- 非本机网段的已建立连接 --"
  ss -tun state established 2>/dev/null | awk 'NR>1 {print "  ", $5}' | grep -vE '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -n 20
fi

# ---- 7. 进程 ----------------------------------------------------------
if has proc; then
  hr "CPU 占用前 10（挖矿常表现为单进程占满）"
  ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -n 11
  echo "-- 从 /tmp、/var/tmp、/dev/shm 启动的进程 --"
  ps -eo pid,cmd | grep -E '(/tmp|/var/tmp|/dev/shm)/' | grep -v grep || echo "  OK：未发现"
fi

printf '\n完成。以上仅为线索，处置前请先备份原始文件。\n'
