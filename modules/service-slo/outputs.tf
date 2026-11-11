output "slo_id" {
  description = "ID of the availability SLO."
  value       = datadog_service_level_objective.availability.id
}
