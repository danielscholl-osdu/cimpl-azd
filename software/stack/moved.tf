# Temporary state migration blocks — remove after first successful apply

# elastic module (8 resources — data source excluded, cannot be moved)
moved {
  from = kubectl_manifest.elasticsearch[0]
  to   = module.elastic[0].kubectl_manifest.elasticsearch
}
moved {
  from = kubectl_manifest.kibana[0]
  to   = module.elastic[0].kubectl_manifest.kibana
}
moved {
  from = kubernetes_service_account.elastic_bootstrap[0]
  to   = module.elastic[0].kubernetes_service_account.elastic_bootstrap[0]
}
moved {
  from = time_sleep.wait_for_eck_reconciliation[0]
  to   = module.elastic[0].time_sleep.wait_for_eck_reconciliation[0]
}
moved {
  from = kubernetes_secret.elastic_bootstrap_secret[0]
  to   = module.elastic[0].kubernetes_secret.elastic_bootstrap_secret[0]
}
moved {
  from = kubernetes_secret.indexer_elastic_secret[0]
  to   = module.elastic[0].kubernetes_secret.indexer_elastic_secret[0]
}
moved {
  from = kubernetes_secret.search_elastic_secret[0]
  to   = module.elastic[0].kubernetes_secret.search_elastic_secret[0]
}
moved {
  from = helm_release.elastic_bootstrap[0]
  to   = module.elastic[0].helm_release.elastic_bootstrap[0]
}

# postgresql module (6 resources)
moved {
  from = kubernetes_secret.postgresql_superuser[0]
  to   = module.postgresql[0].kubernetes_secret.postgresql_superuser
}
moved {
  from = kubernetes_secret.postgresql_user[0]
  to   = module.postgresql[0].kubernetes_secret.postgresql_user
}
moved {
  from = kubectl_manifest.postgresql_cluster[0]
  to   = module.postgresql[0].kubectl_manifest.postgresql_cluster
}
moved {
  from = kubernetes_secret.keycloak_db[0]
  to   = module.postgresql[0].kubernetes_secret.keycloak_db
}
moved {
  from = kubernetes_secret.airflow_db[0]
  to   = module.postgresql[0].kubernetes_secret.airflow_db
}
moved {
  from = kubectl_manifest.cnpg_database_bootstrap[0]
  to   = module.postgresql[0].kubectl_manifest.cnpg_database_bootstrap
}

# redis module (2 resources)
moved {
  from = kubernetes_secret.redis_password[0]
  to   = module.redis[0].kubernetes_secret.redis_password
}
moved {
  from = helm_release.redis[0]
  to   = module.redis[0].helm_release.redis
}

# rabbitmq module (5 resources)
moved {
  from = kubernetes_secret.rabbitmq_credentials[0]
  to   = module.rabbitmq[0].kubernetes_secret.rabbitmq_credentials
}
moved {
  from = kubectl_manifest.rabbitmq_config[0]
  to   = module.rabbitmq[0].kubectl_manifest.rabbitmq_config
}
moved {
  from = kubectl_manifest.rabbitmq_headless_service[0]
  to   = module.rabbitmq[0].kubectl_manifest.rabbitmq_headless_service
}
moved {
  from = kubectl_manifest.rabbitmq_client_service[0]
  to   = module.rabbitmq[0].kubectl_manifest.rabbitmq_client_service
}
moved {
  from = kubectl_manifest.rabbitmq_statefulset[0]
  to   = module.rabbitmq[0].kubectl_manifest.rabbitmq_statefulset
}

# minio module (1 resource)
moved {
  from = helm_release.minio[0]
  to   = module.minio[0].helm_release.minio
}

# keycloak module (7 resources)
moved {
  from = random_password.keycloak_admin[0]
  to   = module.keycloak[0].random_password.keycloak_admin[0]
}
moved {
  from = kubernetes_secret.keycloak_admin[0]
  to   = module.keycloak[0].kubernetes_secret.keycloak_admin
}
moved {
  from = kubernetes_secret.keycloak_db_copy[0]
  to   = module.keycloak[0].kubernetes_secret.keycloak_db_copy
}
moved {
  from = kubernetes_config_map.keycloak_realm[0]
  to   = module.keycloak[0].kubernetes_config_map.keycloak_realm
}
moved {
  from = kubectl_manifest.keycloak_headless_service[0]
  to   = module.keycloak[0].kubectl_manifest.keycloak_headless_service
}
moved {
  from = kubectl_manifest.keycloak_service[0]
  to   = module.keycloak[0].kubectl_manifest.keycloak_service
}
moved {
  from = kubectl_manifest.keycloak_statefulset[0]
  to   = module.keycloak[0].kubectl_manifest.keycloak_statefulset
}
moved {
  from = null_resource.keycloak_jwks_wait[0]
  to   = module.keycloak[0].null_resource.keycloak_jwks_wait
}

# airflow module (4 resources)
moved {
  from = random_bytes.airflow_fernet_key[0]
  to   = module.airflow[0].random_bytes.airflow_fernet_key
}
moved {
  from = random_password.airflow_webserver_secret[0]
  to   = module.airflow[0].random_password.airflow_webserver_secret
}
moved {
  from = kubernetes_secret.airflow_secrets[0]
  to   = module.airflow[0].kubernetes_secret.airflow_secrets
}
moved {
  from = helm_release.airflow[0]
  to   = module.airflow[0].helm_release.airflow
}

# gateway module (4 resources)
moved {
  from = null_resource.gateway_https_listener[0]
  to   = module.gateway[0].null_resource.gateway_https_listener
}
moved {
  from = null_resource.kibana_route[0]
  to   = module.gateway[0].null_resource.kibana_route
}
moved {
  from = kubectl_manifest.kibana_reference_grant[0]
  to   = module.gateway[0].kubectl_manifest.kibana_reference_grant
}
moved {
  from = null_resource.kibana_certificate[0]
  to   = module.gateway[0].null_resource.kibana_certificate[0]
}

# osdu-common module (5 resources)
moved {
  from = kubernetes_namespace.osdu[0]
  to   = module.osdu_common[0].kubernetes_namespace.osdu
}
moved {
  from = kubernetes_config_map.osdu_config[0]
  to   = module.osdu_common[0].kubernetes_config_map.osdu_config
}
moved {
  from = kubernetes_secret.osdu_credentials[0]
  to   = module.osdu_common[0].kubernetes_secret.osdu_credentials
}
moved {
  from = kubernetes_service_account.bootstrap[0]
  to   = module.osdu_common[0].kubernetes_service_account.bootstrap
}
moved {
  from = kubectl_manifest.osdu_peer_authentication[0]
  to   = module.osdu_common[0].kubectl_manifest.osdu_peer_authentication
}

# osdu-common service-specific secrets
moved {
  from = kubernetes_secret.partition_postgres[0]
  to   = module.osdu_common[0].kubernetes_secret.partition_postgres[0]
}
moved {
  from = kubernetes_secret.entitlements_postgres[0]
  to   = module.osdu_common[0].kubernetes_secret.entitlements_postgres[0]
}
moved {
  from = kubernetes_secret.datafier[0]
  to   = module.osdu_common[0].kubernetes_secret.datafier[0]
}
moved {
  from = kubernetes_secret.entitlements_redis[0]
  to   = module.osdu_common[0].kubernetes_secret.entitlements_redis[0]
}
