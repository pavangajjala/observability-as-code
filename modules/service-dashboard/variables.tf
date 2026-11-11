variable "service" {
  description = "Service name as it appears in APM."
  type        = string
}

variable "team" {
  description = "Owning team."
  type        = string
}

variable "envs" {
  description = "Environments offered in the dashboard's env selector. The first one is the default."
  type        = list(string)
}

variable "slo_id" {
  description = "ID of the production availability SLO to show, or null for none."
  type        = string
  default     = null
}

variable "operation" {
  description = "APM operation name the trace metrics are based on."
  type        = string
  default     = "http.request"
}
