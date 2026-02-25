---
status: accepted
date: 2026-02-25
deciders: platform team
---

# KubernetesExecutor for Airflow with NAP task pod scaling

## Context and Problem Statement

Airflow needs an executor strategy for running DAG tasks on AKS Automatic. The executor choice affects resource utilization, scaling behavior, and operational complexity. The cluster already uses Karpenter (NAP) for node auto-provisioning.

## Decision Drivers

- Scale-to-zero for DAG execution (minimize idle compute cost)
- Leverage existing Karpenter NAP infrastructure for dynamic node provisioning
- Minimize operational overhead (no persistent worker fleet to manage)
- AKS Automatic deployment safeguards compliance

## Considered Options

- CeleryExecutor with persistent workers on stateful nodepool
- CeleryExecutor with KEDA autoscaling
- KubernetesExecutor with NAP task pod scaling

## Decision Outcome

Chosen option: "KubernetesExecutor with NAP task pod scaling", because it provides true scale-to-zero, eliminates the need for Redis as a broker, removes the worker fleet management burden, and naturally leverages NAP for right-sized node provisioning per task.

**How it works**: The Airflow scheduler creates an ephemeral pod for each DAG task. Task pods have no tolerations or nodeSelector, so they land on the default pool. NAP detects the pending pod, provisions a right-sized node, runs the task, and consolidates the node after idle timeout. Control-plane components (scheduler, webserver, API server, triggerer) run on the stateful nodepool for stability.

**Chart and image**: Official Apache Airflow Helm chart v1.19.0 with Airflow 3.1.7. The official chart is maintained by the Apache Airflow project and is the recommended deployment method.

### Consequences

- Good, because compute cost scales linearly with actual DAG execution (zero cost when idle)
- Good, because no Redis broker dependency for Airflow (Redis remains available for other services)
- Good, because task pod resource requests can be customized per DAG via pod template overrides
- Good, because NAP automatically selects optimal VM SKUs per task workload
- Bad, because task pod startup includes container pull latency (~10-30s cold start)
- Bad, because very high task concurrency may cause node provisioning delays
