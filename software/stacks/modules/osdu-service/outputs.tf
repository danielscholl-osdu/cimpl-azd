# Outputs for the OSDU service module

output "release_name" {
  description = "Helm release name"
  value       = var.enable && var.enable_common ? helm_release.service[0].name : null
}

output "release_status" {
  description = "Helm release status"
  value       = var.enable && var.enable_common ? helm_release.service[0].status : null
}
