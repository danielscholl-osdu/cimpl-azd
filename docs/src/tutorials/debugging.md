# Debugging Guide

Practical debugging reference for common issues with cimpl-azd deployments. For known issues and workarounds, see also [Troubleshooting](../operations/troubleshooting.md).

## General Pod Debugging

### Check Pod Status

```bash
# All pods in a namespace
kubectl get pods -n foundation
kubectl get pods -n platform
kubectl get pods -n osdu

# Detailed pod info (events, conditions, volumes)
kubectl describe pod <pod-name> -n <namespace>

# Pod logs (current container)
kubectl logs <pod-name> -n <namespace> --tail=100

# Pod logs (previous crash)
kubectl logs <pod-name> -n <namespace> --previous

# Pod logs (specific container in multi-container pod)
kubectl logs <pod-name> -n <namespace> -c <container-name>
```

### Common Pod Issues

| Status | Likely Cause | Debug Command |
|--------|-------------|---------------|
| `Pending` | No schedulable node (resources, taints, affinity) | `kubectl describe pod` — check Events |
| `CrashLoopBackOff` | Application crash on startup | `kubectl logs --previous` |
| `ImagePullBackOff` | Wrong image tag or registry auth | `kubectl describe pod` — check image name |
| `Init:Error` | Init container failed | `kubectl logs -c <init-container>` |
| `Terminating` (stuck) | Finalizers or PVC issues | `kubectl get pod -o yaml` — check finalizers |

---

## Elasticsearch Debugging

### Cluster Health

```bash
# ECK cluster status
kubectl get elasticsearch -n platform
# Expected: health=green, phase=Ready

# Pod status
kubectl get pods -n platform -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch

# Elasticsearch cluster health API
ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user -n platform \
  -o jsonpath='{.data.elastic}' | base64 -d)
kubectl exec -n platform elasticsearch-es-default-0 -- \
  curl -s -k -u "elastic:${ES_PASS}" \
  https://localhost:9200/_cluster/health | python3 -m json.tool
```

### Index Health

```bash
# List indices
kubectl exec -n platform elasticsearch-es-default-0 -- \
  curl -s -k -u "elastic:${ES_PASS}" \
  https://localhost:9200/_cat/indices?v

# Check index templates (created by elastic-bootstrap)
kubectl exec -n platform elasticsearch-es-default-0 -- \
  curl -s -k -u "elastic:${ES_PASS}" \
  https://localhost:9200/_index_template?pretty
```

### Common ES Issues

- **Yellow status**: One or more replica shards unassigned. Check node count — need 3 nodes for green with 1 replica.
- **Red status**: Primary shards unassigned. Check disk space and node health.
- **Bootstrap job failed**: Check `kubectl logs -n platform -l job-name=elastic-bootstrap`.

---

## PostgreSQL Debugging

### CNPG Cluster Status

```bash
# Cluster status
kubectl get clusters.postgresql.cnpg.io -n platform
# Expected: "Cluster in healthy state"

# Detailed cluster info
kubectl describe clusters.postgresql.cnpg.io postgresql -n platform

# Pod status
kubectl get pods -n platform -l cnpg.io/cluster=postgresql
```

### Connection Testing

```bash
# Port-forward to primary
kubectl port-forward -n platform svc/postgresql-rw 5432:5432 &

# Test connection (requires psql)
PG_PASS=$(kubectl get secret postgresql-superuser-secret -n platform \
  -o jsonpath='{.data.password}' | base64 -d)
PGPASSWORD=$PG_PASS psql -h localhost -U postgres -d postgres -c "SELECT version();"

# List databases
PGPASSWORD=$PG_PASS psql -h localhost -U postgres -d postgres -c "\l"
```

### Common PG Issues

- **Cluster not ready**: CNPG initdb Jobs may be blocked by Gatekeeper probes. Check if the Azure Policy exemption exists.
- **Connection refused**: Check if pods are running and service endpoints exist.
- **Missing tables**: Check the DDL bootstrap job logs in `kubectl logs -n platform -l cnpg.io/jobRole=initdb`.

---

## Keycloak Debugging

### Admin Access

```bash
# Port-forward to Keycloak
kubectl port-forward -n platform svc/keycloak 8080:8080 &

# Open http://localhost:8080 in browser
# Username: admin
# Password:
kubectl get secret keycloak-admin-credentials -n platform \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

### Realm Verification

```bash
# Check if osdu realm exists
curl -s http://localhost:8080/realms/osdu/.well-known/openid-configuration | python3 -m json.tool

# Check JWKS endpoint (must return keys for OSDU services to validate tokens)
curl -s http://localhost:8080/realms/osdu/protocol/openid-connect/certs | python3 -m json.tool
```

### Common Keycloak Issues

- **JWKS wait timeout**: The `keycloak_jwks_wait` null_resource polls for JWKS readiness. If Keycloak is slow to start, subsequent OSDU services may fail.
- **Realm not imported**: Check pod logs for import errors: `kubectl logs -n platform -l app=keycloak`.
- **datafier client missing**: Bootstrap entitlements will fail. Verify the client exists in the osdu realm.

---

## RabbitMQ Debugging

### Cluster Health

```bash
# Pod status
kubectl get pods -n platform -l app=rabbitmq

# Cluster status
kubectl exec -n platform rabbitmq-0 -- rabbitmqctl cluster_status

# Queue list
kubectl exec -n platform rabbitmq-0 -- rabbitmqctl list_queues
```

### Management UI

```bash
# Port-forward to management plugin
kubectl port-forward -n platform svc/rabbitmq-management 15672:15672 &
# Open http://localhost:15672
# Credentials from rabbitmq-credentials secret
```

### Common RabbitMQ Issues

- **Split brain**: If pods restart across zones, cluster may partition. Check `rabbitmqctl cluster_status` for partitioned nodes.
- **Queues not draining**: Consumer service may be down. Check OSDU service pods.
- **No Istio sidecar**: RabbitMQ pods have `sidecar.istio.io/inject: "false"` — this is expected. RabbitMQ requires `NET_ADMIN` capabilities blocked by AKS Automatic.

---

## Gateway & Ingress Debugging

### HTTPRoute Status

```bash
# List all HTTPRoutes
kubectl get httproute -A

# Check HTTPRoute conditions
kubectl describe httproute <route-name> -n <namespace>

# Check gateway status
kubectl get gateway -n aks-istio-ingress
```

### Certificate Issues

```bash
# Check certificate status (certificates are in the stack namespace)
kubectl get certificates -n platform
# Expected: Ready=True

# Check certificate details
kubectl describe certificate <cert-name> -n platform

# Check cert-manager logs
kubectl logs -n foundation -l app.kubernetes.io/name=cert-manager --tail=50
```

### Common Ingress Issues

- **No external IP**: Check if `enable_public_ingress` is true. Verify the Istio ingress gateway service: `kubectl get svc -n aks-istio-ingress`.
- **Certificate pending**: HTTP-01 challenge may be failing. Check cert-manager logs in the `foundation` namespace and ensure DNS points to the external IP.
- **404 responses**: HTTPRoute may not match. Check route hostnames and backend service references.

---

## Istio / Service Mesh Debugging

### Sidecar Injection

```bash
# Verify namespace labels (both should have istio-injection: enabled)
kubectl get ns platform --show-labels
kubectl get ns osdu --show-labels

# Check sidecar status in a namespace
kubectl get pods -n platform -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
# Most pods should have an istio-proxy container (except RabbitMQ)
```

### mTLS Verification

```bash
# Check PeerAuthentication (both namespaces should show STRICT)
kubectl get peerauthentication -n platform
kubectl get peerauthentication -n osdu
```

---

## OSDU Service Debugging

### Service Health Check

```bash
# Direct health probe (from inside the cluster)
kubectl exec -n osdu <any-pod> -c <container> -- \
  curl -s http://partition.osdu.svc.cluster.local:80/api/partition/v1/health

# Check management port probes
kubectl exec -n osdu <pod-name> -c <service-name> -- \
  curl -s http://localhost:8081/health/liveness
```

### Bootstrap Failures

```bash
# Check bootstrap pod logs
kubectl logs -n osdu -l app=partition,type=bootstrap --tail=100

# Bootstrap pods call the service API — check if the target service is healthy first
kubectl get pods -n osdu -l app=partition,type=core
```

### Common OSDU Service Issues

- **Slow startup**: Java services take 2-5 minutes. Check `initialDelaySeconds` in probe configuration.
- **Database connection refused**: Verify PostgreSQL is healthy and the service's postgres secret exists in the `osdu` namespace.
- **401 Unauthorized**: Token validation failing — check Keycloak JWKS endpoint and Istio mTLS configuration.
- **Partition service returns empty**: Bootstrap may not have run. Check bootstrap pod logs.

---

## Node & Scheduling Debugging

### Node Issues

```bash
# List nodes with status
kubectl get nodes -o wide

# Check Karpenter provisioning
kubectl get nodeclaim
kubectl get nodepool

# Check for scheduling failures
kubectl get events --field-selector reason=FailedScheduling -A
```

### Resource Pressure

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n platform
kubectl top pods -n osdu
```
