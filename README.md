# 李家俊 · 运维实践作品集

计算机网络技术（专科）· 2027 届 · 求职方向：IT 运维 / 桌面支持

这里存放我在课程实训和个人练习中完成的运维实践，重点是可复现的操作与真实的排障过程。

## 内容

| 目录 | 内容 | 关键点 |
|---|---|---|
| [`incident-response/`](incident-response/) | Linux 主机入侵排查与应急处置记录 | 命令劫持识别、cron 持久化追踪、自恢复脚本、后门账号与 SSH 公钥 |
| [`harbor/`](harbor/) | 基于 Linux 部署 Harbor 私有镜像仓库 | 双机规划、Docker Compose 编排、insecure-registries、全链路验证 |
| [`scripts/`](scripts/) | 日常运维小工具 | `linux_health_check.sh`：只读的主机快速体检 |

## 环境与边界

- 应急响应的对象是**在线攻防靶场的隔离靶机**，不是生产环境；文中已隐去账号口令等敏感信息。
- Harbor 部署在本地 VMware 虚拟机上，双机静态 IP。
- 所有脚本均为只读检查，不修改目标主机。

## 联系

- 邮箱：877356490@qq.com
