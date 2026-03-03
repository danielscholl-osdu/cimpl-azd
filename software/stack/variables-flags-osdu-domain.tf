# Feature flags — OSDU Domain Services

variable "enable_osdu_domain_services" {
  description = "Master switch for all OSDU domain services (requires core)"
  type        = bool
  default     = false
}

variable "enable_wellbore" {
  description = "Enable OSDU Wellbore service deployment"
  type        = bool
  default     = false
}

variable "enable_wellbore_worker" {
  description = "Enable OSDU Wellbore Worker service deployment"
  type        = bool
  default     = false
}

variable "enable_eds_dms" {
  description = "Enable OSDU EDS-DMS service deployment"
  type        = bool
  default     = false
}
