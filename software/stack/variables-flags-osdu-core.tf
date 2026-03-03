# Feature flags — OSDU Core Services

variable "enable_osdu_core_services" {
  description = "Master switch for all OSDU core services (partition through workflow)"
  type        = bool
  default     = true
}

variable "enable_common" {
  description = "Enable OSDU common namespace resources"
  type        = bool
  default     = true
}

variable "enable_partition" {
  description = "Enable OSDU Partition service deployment"
  type        = bool
  default     = true
}

variable "enable_entitlements" {
  description = "Enable OSDU Entitlements service deployment"
  type        = bool
  default     = true
}

variable "enable_legal" {
  description = "Enable OSDU Legal service deployment"
  type        = bool
  default     = true
}

variable "enable_schema" {
  description = "Enable OSDU Schema service deployment"
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "Enable OSDU Storage service deployment"
  type        = bool
  default     = true
}

variable "enable_search" {
  description = "Enable OSDU Search service deployment"
  type        = bool
  default     = true
}

variable "enable_indexer" {
  description = "Enable OSDU Indexer service deployment"
  type        = bool
  default     = true
}

variable "enable_file" {
  description = "Enable OSDU File service deployment"
  type        = bool
  default     = true
}

variable "enable_notification" {
  description = "Enable OSDU Notification service deployment"
  type        = bool
  default     = true
}

variable "enable_dataset" {
  description = "Enable OSDU Dataset service deployment"
  type        = bool
  default     = true
}

variable "enable_register" {
  description = "Enable OSDU Register service deployment"
  type        = bool
  default     = true
}

variable "enable_policy" {
  description = "Enable OSDU Policy service deployment"
  type        = bool
  default     = true
}

variable "enable_secret" {
  description = "Enable OSDU Secret service deployment"
  type        = bool
  default     = true
}

variable "enable_workflow" {
  description = "Enable OSDU Workflow service deployment"
  type        = bool
  default     = true
}
