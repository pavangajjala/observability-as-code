variable "service" {
  description = "Service name as it appears in APM."
  type        = string
}

variable "env" {
  description = "Environment tag the SLO is scoped to."
  type        = string
}

variable "team" {
  description = "Owning team."
  type        = string
}

variable "target" {
  description = "Availability target in percent over 30 days, for example 99.9."
  type        = number

  validation {
    condition     = var.target >= 90 && var.target < 100
    error_message = "target must be at least 90 and below 100."
  }
}

variable "page_handle" {
  description = "Who is paged when the error budget burns fast. Null creates the SLO without a paging alert."
  type        = string
  default     = null
}

variable "ticket_handle" {
  description = "Where slow-burn alerts go (a team channel or ticket queue)."
  type        = string
}

variable "operation" {
  description = "APM operation name the trace metrics are based on."
  type        = string
  default     = "http.request"
}
