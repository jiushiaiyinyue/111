# Linux 主机入侵排查与应急处置（靶机演练）

> 对象：在线攻防靶场分配的 Ubuntu 20.04 隔离靶机，非生产环境。
> 记录方式：按处置时间线整理，命令与输出以截图为准。

## 1. 发现：从一个 `alias` 开始

登录后先执行 `alias`，发现 14 个排查命令被重定义：

```bash
alias adduser='printf ""'
alias crontab='printf ""'
alias find='printf ""'
alias kill='printf ""'
alias ps='printf ""'
alias ss='printf ""'
alias netstat='printf ""'
# …共 14 个
```

`ps`、`ss`、`netstat`、`crontab` 恰好覆盖了排查最常用的四类操作（进程、连接、定时任务、账号），
而 `cp`、`mv`、`rm` 仍是原命令——攻击者只屏蔽"看"的能力，不影响"用"的能力。

**结论：排查前必须先确认命令本身可信。** 后续所有排查都改用绝对路径或 `command builtin`。

## 2. 持久化：crontab 里的三条线索

```bash
sudo crontab -l
```

```text
@daily   /home/<user>/.b<redacted>
@reboot  /home/<user>/.p<redacted> > /dev/null 2>&1 & disown
* * * * * /home/<user>/.p<redacted> > /dev/null 2>&1 & disown
@monthly /home/<user>/.p<redacted>
```

三个特征：

1. `./` 开头的家目录隐藏文件，不是系统命令；
2. 每条都带 `> /dev/null 2>&1 & disown`，丢弃输出并脱离当前 shell 的作业表；
3. **每分钟**拉起一次——杀进程没有意义，必须断掉 cron。

## 3. 脚本分析

两个隐藏脚本分工明确：

- 挖矿脚本：`pgrep -x ethminer` 判断矿工是否存活，未存活则进入 `~/bin` 启动
  `ethminer`，参数包含钱包地址、邮箱、矿池与 `--report-hashrate`。
- 投递脚本：内置后门账号与 SSH 公钥，并定义了从远端下载 `ethminer.tar`、解压、
  将 `bin` 目录权限改为 `777` 的函数。

## 4. 隐藏入口：`.bashrc` 的 `source` 注入

```bash
cat ~/.bashrc        # 第一行：source /var/tmp/.<redacted>/.db
cat /root/.bashrc    # 第一行：source /usr/.<redacted>/.db
```

恶意脚本的行为链：

1. `rm -rf ~/.bashrc`、`rm -rf ~/.bash_history`（销毁痕迹）；
2. 批量把排查命令 alias 成 `printf ""`；
3. 用 `echo '…' > ~/.bashrc` 把 `source` 写回去（**自恢复**）。

所以删掉 `.bashrc` 也没用：下次登录执行到 `.db`，`.bashrc` 会被重新生成。
用户目录与 root 目录各放一份，删一个另一个还在。

## 5. 研判与确认

| 证据 | 手段 |
|---|---|
| 矿池域名 `eth-asia1.nanopool.org:9999` | 威胁情报平台查询，判定为 CoinMiner 家族 |
| 钱包地址 | 与脚本中的挖矿参数交叉比对 |
| `getent passwd` 输出中 `sclipticbosu:x:0:0::/home/...` | UID=GID=0，与投递脚本里写死的用户名一致 → 后门账号 |
| `authorized_keys` 中非本人的公钥 | 持久化登录方式 |

## 6. 处置

```bash
mkfs 之前先备份：cp -a ~/.bashrc /root/.bash_history /root/ir_backup/
```

1. 备份原始文件（`.bashrc`、`.db`、两个隐藏脚本）到 `/root/ir_backup/`；
2. 清除 alias 污染，**逐行删除**而不是删半截（我第一次删留了 `alias` 和 `-i` 两段残片，
   重新登录报 `alias: -i: 未找到`，见踩坑记录）；
3. 删除 `crontab` 中的四条任务；
4. 删除 UID=0 后门账号与 `authorized_keys` 中的陌生公钥；
5. 重新登录，`alias` 无输出、`ps`/`ss` 恢复真实输出即验证通过。

## 7. 踩坑记录

清理 `.bashrc` 时只删了恶意行的前半截，留下 `alias` 与 `-i` 不完整的片段，
导致每次登录 bash 报三次 `alias: -i: 未找到`。原因：`.profile` 加载 `.bashrc` 时
仍会执行残留行。**教训：清理 shell 配置要整行删除，并重新登录验证，而不是只看当前会话。**

## 8. 复盘

如果换成真实生产环境，顺序应该调整为先上报、隔离主机、保护现场，再开始排查；
本次是隔离靶机，因此直接进入技术排查。另外，攻击者只用了 alias + cron + shell 配置，
没有动内核模块和 PAM，说明这仍是低成本的常见手法——**先看 alias，再看 cron** 应该成为固定动作。
