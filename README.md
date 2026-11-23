# k8s-zero-downtime-deployment

Multi-environment Kubernetes deployment pipeline built on [k3d](https://k3d.io/), demonstrating namespace isolation, rolling updates, Ingress routing, and RBAC — all wrapped in a ready-to-use VS Code Dev Container.

The workload is [`hashicorp/http-echo`](https://hub.docker.com/r/hashicorp/http-echo), a tiny HTTP server that echoes back a configurable string. Each environment gets its own response text, making it easy to verify which namespace you're actually hitting.

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start (Dev Container)](#quick-start-dev-container)
- [Quick Start (Manual)](#quick-start-manual)
- [Environments](#environments)
- [Deploying the Stack](#deploying-the-stack)
- [Accessing the Application](#accessing-the-application)
- [Rolling Updates & Zero Downtime](#rolling-updates--zero-downtime)
- [RBAC](#rbac)
- [Cleanup](#cleanup)
- [Helper Scripts Reference](#helper-scripts-reference)

---

## Architecture

- **Three isolated namespaces** (`dev`, `staging`, `prod`), each with its own `ConfigMap`, `Deployment`, and `Service`.
- **Ingress** (Traefik) is only configured for `prod`, exposed via `api.127.0.0.1.nip.io:8080`.
- **RBAC** grants a `developer` ServiceAccount full access to `dev` and read-only access to `staging`.

---

## Project Structure

```
.
├── .devcontainer/
│   ├── devcontainer.json            # Dev Container definition
│   └── scripts/
│       ├── install.sh               # Installs k3d on container creation
│       └── start-cluster.sh         # Boots the k3d cluster on container start
├── dev/                             # dev environment manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── staging/                         # staging environment manifests
│   └── ...
├── prod/                            # prod environment manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml              # rolling update + readiness probe + resource limits
│   ├── service.yaml
│   └── ingress.yaml                 # Traefik ingress (api.127.0.0.1.nip.io)
├── rbac/                            # Role / RoleBinding / ServiceAccount
│   ├── serviceaccount-dev.yaml
│   ├── role-dev.yaml
│   ├── rolebinding-dev.yaml
│   ├── role-staging.yaml
│   └── rolebinding-staging.yaml
├── rollout.sh                       # Apply everything in order + wait for rollouts
├── delete-rollout.sh                # Tear down dev/staging/prod resources
└── setup-k3-cluster.sh              # Standalone k3d cluster bootstrap (non-devcontainer)
```

---

## Prerequisites

**With the Dev Container** — nothing. Docker + VS Code are the only host requirements.

**Without the Dev Container** you'll need:

| Tool | Version |
|------|---------|
| [Docker](https://docs.docker.com/get-docker/) | 20.10+ |
| [k3d](https://k3d.io/) | 5.x |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.27+ |
| bash | 4.x |

---

## Quick Start (Dev Container)

The fastest path. Requires VS Code + the **Dev Containers** extension.

1. Open the repository in VS Code.
2. When prompted, click **Reopen in Container** (or run `Dev Containers: Reopen in Container`).
3. The container will automatically:
   - Install **k3d** (`install.sh`)
   - Create the `k8s-lab` cluster with 1 server + 2 agents (`start-cluster.sh`)
   - Merge the kubeconfig and wait for nodes to be `Ready`
4. Forwarded ports **8080** (HTTP) and **8443** (HTTPS) are available on your host.

Verify:

```bash
kubectl get nodes
kubectl get pods -A
```

Then deploy the stack:

```bash
./rollout.sh
```

---

## Quick Start (Manual)

```bash
# 1. Create the cluster (ports 8080/8443 mapped to the load balancer)
./setup-k3-cluster.sh

# 2. Deploy namespaces, RBAC, and all environments
./rollout.sh
```

> `setup-k3-cluster.sh` is destructive — it will **delete** an existing cluster named `default` before recreating it.

---

## Environments

| Environment | Namespace | Replicas | Response Text | Ingress | RBAC (via `developer` SA) |
|-------------|-----------|----------|---------------|---------|---------------------------|
| **dev**     | `dev`     | 1        | `Hello from DEV - v1` | — | full access (`*`) |
| **staging** | `staging` | 2        | `Hello from Staging.` | — | read-only |
| **prod**    | `prod`    | 3        | `Hello from Production.` | ✅ | — |

The response text is injected via each namespace's `api-config` ConfigMap.

---

## Deploying the Stack

```bash
./rollout.sh
```

To verify:

```bash
kubectl get deploy,po,svc -n dev
kubectl get deploy,po,svc -n staging
kubectl get deploy,po,svc -n prod
```

---

## Accessing the Application

The prod service is exposed via the Traefik ingress at the host `api.127.0.0.1.nip.io`. With the k3d cluster mapping `8080 → 80@loadbalancer`:

```bash
curl http://api.127.0.0.1.nip.io:8080
# → Hello from Production.
```

---

## Rolling Updates & Zero Downtime

The **prod** deployment is configured for zero-downtime rollouts:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0   # never take a pod out of service during rollout
    maxSurge: 1         # spin up 1 extra pod at a time
```

It also defines a `readinessProbe` on `/` (port 5678) so Kubernetes only routes traffic to pods that are actually serving, plus resource requests/limits to keep scheduling predictable.

To demonstrate a zero-downtime deploy, edit `prod/configmap.yaml`:

```yaml
data:
  RESPONSE_TEXT: "Hello from Production — v2"
```

Then:

```bash
kubectl apply -f prod/
kubectl rollout status deployment/api -n prod --timeout 100s
```

In a separate terminal, hammer the endpoint while the rollout runs:

```bash
while true; do curl -s http://api.127.0.0.1.nip.io:8080; echo; sleep 0.2; done
```

You should see responses flip from `v1` → `v2` without any connection errors.

---

## RBAC

The `rbac/` directory provisions a single `developer` ServiceAccount in the `dev` namespace and binds it to two roles:

| Resource | Namespace | Detail |
|----------|-----------|--------|
| `ServiceAccount/developer` | `dev` | The identity used by devs |
| `Role/dev-full-access` | `dev` | `apiGroups: *`, `resources: *`, `verbs: *` |
| `Role/staging-readonly` | `staging` | `get`, `list`, `watch` on all resources |
| `RoleBinding/dev-full-access-binding` | `dev` | Binds `developer` → `dev-full-access` |
| `RoleBinding/staging-readonly-binding` | `staging` | Binds `developer` → `staging-readonly` |

Test it:

```bash
# Should succeed
kubectl auth can-i create pods --as=system:serviceaccount:dev:developer -n dev

# Should fail (read-only)
kubectl auth can-i delete pods --as=system:serviceaccount:dev:developer -n staging
```

---

## Cleanup

```bash
# Delete application resources (namespaces, RBAC, all envs)
./delete-rollout.sh

# Or nuke the whole cluster
k3d cluster delete k8s-lab        # if using the devcontainer scripts
k3d cluster delete default        # if using setup-k3-cluster.sh
```

---

## Helper Scripts Reference

| Script | Purpose |
|--------|---------|
| `setup-k3-cluster.sh` | Standalone k3d bootstrap (cluster `default`, port 8080→80). **Destructive.** |
| `rollout.sh` | Applies namespaces → RBAC → envs → waits for rollout status on all three deployments. |
| `delete-rollout.sh` | Deletes `dev/`, `staging/`, `prod/` manifests. |

## Sources
- .devcontainer code originally based on [lbrenman/k3d-codespace](https://github.com/lbrenman/k3d-codespace)