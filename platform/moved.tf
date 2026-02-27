# State migration blocks for OSDU service refactoring
#
# These moved blocks tell Terraform that existing helm_release resources
# have been reorganized into the osdu-service module. They prevent
# destroy+recreate cycles during the transition.
#
# Keep until ALL environments/states have applied this refactor.
# Removing before every env migrates will cause destroy+recreate in lagging states.

moved {
  from = helm_release.partition[0]
  to   = module.partition.helm_release.service[0]
}

moved {
  from = helm_release.entitlements[0]
  to   = module.entitlements.helm_release.service[0]
}
