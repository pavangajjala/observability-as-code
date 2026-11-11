output "dashboards" {
  description = "Dashboard URL per service."
  value       = { for name, dashboard in module.dashboard : name => dashboard.url }
}

output "monitor_count" {
  description = "Number of monitors under management."
  value       = sum([for m in module.monitors : length(m.monitor_ids)]) + 2 * length(module.slo)
}
