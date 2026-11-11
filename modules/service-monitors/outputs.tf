output "monitor_ids" {
  description = "IDs of the monitors created for this service."
  value = merge(
    {
      error_rate = datadog_monitor.error_rate.id
      latency    = datadog_monitor.latency.id
    },
    length(datadog_monitor.no_traffic) > 0 ? { no_traffic = datadog_monitor.no_traffic[0].id } : {},
  )
}
