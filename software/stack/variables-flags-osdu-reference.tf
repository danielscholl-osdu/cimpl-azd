# Feature flags — OSDU Reference Services

variable "enable_osdu_reference_services" {
  description = "Master switch for all OSDU reference services (requires core)"
  type        = bool
  default     = true
}

variable "enable_unit" {
  description = "Enable OSDU Unit service deployment"
  type        = bool
  default     = true
}

variable "enable_crs_conversion" {
  description = "Enable OSDU CRS Conversion service deployment"
  type        = bool
  default     = true
}

variable "enable_crs_catalog" {
  description = "Enable OSDU CRS Catalog service deployment"
  type        = bool
  default     = true
}
