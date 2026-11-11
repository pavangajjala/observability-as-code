locals {
  catalog      = yamldecode(file(var.catalog_file))
  default_envs = local.catalog.defaults.envs
  services     = local.catalog.services

  # One entry per service and environment, keyed "service/env".
  service_envs = merge([
    for name, svc in local.services : {
      for env in try(svc.envs, local.default_envs) : "${name}/${env}" => {
        service = name
        env     = env
        config  = svc
      }
    }
  ]...)

  # SLOs are defined for production only: staging has no users to make a
  # promise to, and its traffic is too thin for a meaningful ratio.
  slo_services = {
    for name, svc in local.services : name => svc
    if try(svc.slo_target, null) != null && contains(try(svc.envs, local.default_envs), "prod")
  }
}

module "monitors" {
  source   = "../modules/service-monitors"
  for_each = local.service_envs

  service = each.value.service
  env     = each.value.env
  team    = each.value.config.team
  tier    = each.value.config.tier

  notify = {
    page    = try(each.value.config.notify.page, null)
    channel = each.value.config.notify.channel
  }

  error_rate          = try(each.value.config.error_rate, {})
  latency_p95_seconds = try(each.value.config.latency_p95_seconds, {})
  runbook_url         = try(each.value.config.runbook_url, null)
  operation           = try(each.value.config.operation, "http.request")
}

module "slo" {
  source   = "../modules/service-slo"
  for_each = local.slo_services

  service = each.key
  env     = "prod"
  team    = each.value.team
  target  = each.value.slo_target

  # Fast burn pages only where there is a pager; otherwise both alerts go to the channel.
  page_handle   = try(each.value.notify.page, each.value.notify.channel)
  ticket_handle = each.value.notify.channel
  operation     = try(each.value.operation, "http.request")
}

module "dashboard" {
  source   = "../modules/service-dashboard"
  for_each = local.services

  service   = each.key
  team      = each.value.team
  envs      = try(each.value.envs, local.default_envs)
  slo_id    = try(module.slo[each.key].slo_id, null)
  operation = try(each.value.operation, "http.request")
}
