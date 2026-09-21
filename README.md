# gv_chat_turn

Standalone TURN relay for App WebRTC calls. Signalling, call control, user authentication, and all business integrations remain outside this service.

## Configuration

| Variable | Development default | Production requirement |
| --- | --- | --- |
| `NODE_ENV` | `development` | Set to `production` |
| `TURN_LISTENING_PORT` | `3478` | Optional; valid TCP/UDP port |
| `TURN_RELAY_MIN_PORT` | `49152` | Optional; lower bound of the UDP relay range |
| `TURN_RELAY_MAX_PORT` | `65535` | Optional; upper bound of the UDP relay range |
| `TURN_EXTERNAL_IP` | `192.168.1.39` | Required; public IP advertised to clients |
| `TURN_USERNAME` | `turnuser` | Required; inject with a Kubernetes Secret |
| `TURN_PASSWORD` | `dev-turn-password` | Required; inject with a Kubernetes Secret |

Development can run with the defaults:

```powershell
node index.js
```

For a production container, inject all production values through the deployment environment. The process refuses to start if the external IP or either credential is missing.

## Kubernetes

[`k8s/turn.yaml`](k8s/turn.yaml) deploys into `im-business` using the existing ACR image pull Secret and references the separately managed production ConfigMap and Secret. It creates an ACK internet-facing UDP LoadBalancer for port `3478`. Set `TURN_EXTERNAL_IP` to the allocated VIP and ensure `turn.dev.example.com` resolves to that IP. A TURN URI uses `turn:turn.dev.example.com:3478?transport=udp`; TLS certificates and HTTP Ingress do not apply to UDP TURN.

The Deployment requests `100m` CPU and `128Mi` memory, with limits of `1` CPU and `512Mi`. These are safe baseline reservations; size them from concurrent relay sessions and observed traffic before production rollout. The deployed baseline uses relay ports `49152-49200/UDP` (49 concurrent allocations); expand the range only with a corresponding ACK LoadBalancer port configuration.

```powershell
kubectl apply -f k8s/turn.yaml
```

The included static credential setup is suitable only as a configurable baseline. Rotate the Secret regularly; for stronger production security, issue short-lived TURN credentials from the application backend. The installed `node-turn` version exposes a UDP listener; this manifest intentionally does not advertise unsupported TCP TURN. Every allocation also needs a UDP relay port in `TURN_RELAY_MIN_PORT` through `TURN_RELAY_MAX_PORT` reachable on the same public endpoint. This cannot be provided by an HTTP Ingress or by the single 3478 Service listener.
