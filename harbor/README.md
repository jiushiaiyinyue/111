# 基于 Linux 的 Harbor 私有镜像仓库部署与验证

在 VMware 上以 server / client 双机完成 Harbor v2.5.5 的部署与全链路验证，
目的是解决实验室内网无法稳定访问公共镜像仓库、镜像分发不可控的问题。

## 拓扑与地址规划

| 角色 | IP | 作用 |
|---|---|---|
| server | 10.28.3.137 | Docker + Docker Compose + Harbor |
| client | 10.28.3.138 | 访问 Web、登录、推拉镜像、运行容器 |

Harbor Web：`http://10.28.3.137`
客户端验证地址：`http://10.28.3.138:8080`

## 部署步骤

```bash
# 1. 环境检查
docker --version && docker-compose --version

# 2. 解压离线安装包
tar xvf harbor-offline-installer-v2.5.5.tgz && cd harbor
cp harbor.yml.tmpl harbor.yml

# 3. 关键配置
#    hostname: 10.28.3.137
#    http.port: 80
#    data_volume: /opt/data/harbor
#    （未配置 SSL，HTTPS 段保持注释）
mkdir -p /opt/data/harbor

# 4. 安装并启动
./install.sh
docker-compose ps    # 期望全部 Up (healthy)
```

## 关键问题：HTTP 仓库登录失败

Harbor 用 HTTP 部署时，Docker 客户端默认按 HTTPS 访问，`docker login` 会直接失败。
解决方式是在客户端登记不安全仓库：

```bash
vi /etc/docker/daemon.json
```

```json
{ "insecure-registries": ["10.28.3.137"] }
```

```bash
systemctl daemon-reload && systemctl restart docker && systemctl status docker
```

## 全链路验证

```bash
docker login 10.28.3.137                          # Login Succeeded
docker tag httpd:2.2.32 10.28.3.137/library/httpd:2.2.32
docker push 10.28.3.137/library/httpd:2.2.32      # 各层 Pushed + digest
# 在 client 端
docker pull 10.28.3.137/library/httpd:2.2.32
docker run -d -p 8080:80 10.28.3.137/library/httpd:2.2.32
# 浏览器访问 http://10.28.3.138:8080 → "It works!"
```

## 组件与结果

Docker Compose 编排 9 个容器：`harbor-core`、`harbor-db`、`harbor-jobservice`、
`harbor-log`、`harbor-portal`、`nginx`、`redis`、`registry`、`registryctl`，
全部处于 `Up (healthy)`。

## 待改进

本次只做到 HTTP 可用，以下三项是下一步计划：

- [ ] 自签 CA 配置 HTTPS，取消 insecure-registries
- [ ] 项目权限与机器人账号（robot account），按最小权限发放
- [ ] 启用 Trivy 镜像扫描与镜像清理策略
