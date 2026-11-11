variable "datadog_api_url" {
  description = "Datadog API endpoint for your site (EU: https://api.datadoghq.eu/)."
  type        = string
  default     = "https://api.datadoghq.com/"
}

variable "catalog_file" {
  description = "Path to the service catalog."
  type        = string
  default     = "../catalog/services.yaml"
}
