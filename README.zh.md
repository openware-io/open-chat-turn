# open-chat-turn

[中文](README.zh.md) | [English](README.md)

独立的 TURN 中继服务，供 App WebRTC 通话使用。信令、通话控制、用户认证和业务集成均不在本服务内。

## 配置

| 变量 | 开发默认值 | 生产要求 |
| --- | --- | --- |
| `NODE_ENV` | `development` | 设置为 `production` |
| `TURN_LISTENING_PORT` | `3478` | 可选；合法的 TCP/UDP 端口 |
| `TURN_RELAY_MIN_PORT` | `49152` | 可选；UDP 中继范围下界 |
| `TURN_RELAY_MAX_PORT` | `65535` | 可选；UDP 中继范围上界 |
| `TURN_EXTERNAL_IP` | `203.0.113.10` | 必填；向客户端公布的公网 IP |
| `TURN_USERNAME` | `turnuser` | 必填；通过 Kubernetes Secret 注入 |
| `TURN_PASSWORD` | `dev-turn-password` | 必填；通过 Kubernetes Secret 注入 |

开发环境可使用默认值：

```powershell
node index.js
```

生产容器必须通过部署环境注入全部生产值。缺少外部 IP 或任一凭据时进程拒绝启动。

## Kubernetes

[`k8s/turn.yaml`](k8s/turn.yaml) 部署到 `im-business`，复用现有 ACR 拉取 Secret，并引用独立管理的生产 ConfigMap 和 Secret。它创建面向互联网的 UDP LoadBalancer，监听 `3478`。将 `TURN_EXTERNAL_IP` 设置为分配的 VIP，并确保 `turn.dev.example.com` 解析到该 IP。TURN URI 形如 `turn:turn.dev.example.com:3478?transport=udp`；TLS 证书和 HTTP Ingress 不适用于 UDP TURN。

Deployment 请求 `100m` CPU、`128Mi` 内存，限制为 `1` CPU、`512Mi`。这是安全基线，生产上线前应按并发中继会话和实际流量调整。当前基线使用 `49152-49200/UDP` 中继端口（49 个并发分配）；扩大范围时必须同步配置 ACK LoadBalancer 端口。

```powershell
kubectl apply -f k8s/turn.yaml
```

内置静态凭据仅作为可配置基线。应定期轮换 Secret；更高安全要求下由应用后端签发短期 TURN 凭据。当前 `node-turn` 版本只暴露 UDP 监听，清单不声明不支持的 TCP TURN。每个分配还需要在 `TURN_RELAY_MIN_PORT` 到 `TURN_RELAY_MAX_PORT` 范围内、同一公网端点可达的 UDP 中继端口；HTTP Ingress 或单个 `3478` Service 监听无法提供该能力。
