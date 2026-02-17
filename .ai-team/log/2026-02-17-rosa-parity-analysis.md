# Session: 2026-02-17 — ROSA Parity Gap Analysis

**Requested by:** Daniel Scholl

**Who worked:** Holden (Lead) — Full gap analysis of ROSA reference architecture vs AKS implementation

**What was done:**
- Analyzed 8 infrastructure components (Istio, Common, Airflow, Elasticsearch, Keycloak, MinIO, PostgreSQL, RabbitMQ)
- Analyzed ~22 OSDU services and dependency chains
- Identified 4 missing infra components (Common, Keycloak, RabbitMQ, Airflow)
- Identified all ~22 OSDU services as missing from AKS implementation
- Documented 10 open architectural questions requiring user input before implementation can proceed

**Decisions Captured:**
1. AKS-managed Istio is the correct approach (confirmed) — ROSA uses self-managed, but AKS Automatic blocks NET_ADMIN/NET_RAW
2. Elasticsearch strategy: AKS uses ECK Operator (better safeguards control) vs ROSA CIMPL chart
3. PostgreSQL upgrade: AKS CloudNativePG (3-instance HA) vs ROSA single-instance CIMPL chart; services must use `postgresql-rw.postgresql.svc.cluster.local`
4. Service namespace strategy: Recommend single `osdu` namespace for all services (vs per-component namespaces)

**Open Questions:** 10 documented for Daniel (Keycloak capability, Common chart purpose, etc.)

**Outcome:** Parity plan framework established; Phase 1 complete (analysis done).
