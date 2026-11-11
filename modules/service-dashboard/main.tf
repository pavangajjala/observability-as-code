locals {
  scope = "service:${var.service},$env"
}

# One dashboard per service, laid out the same way for every service, so
# whoever is on call knows where to look without learning each team's layout.
resource "datadog_dashboard" "service" {
  title       = "${var.service} overview"
  description = "Golden signals for ${var.service}. Owned by ${var.team}. Managed by Terraform; changes made in the UI will be overwritten."
  layout_type = "ordered"
  reflow_type = "fixed"

  tags = ["team:${var.team}"]

  template_variable {
    name             = "env"
    prefix           = "env"
    available_values = var.envs
    defaults         = [var.envs[0]]
  }

  widget {
    widget_layout {
      x      = 0
      y      = 0
      width  = 4
      height = 2
    }

    query_value_definition {
      title     = "Requests per second"
      autoscale = true
      precision = 1

      request {
        q          = "sum:trace.${var.operation}.hits{${local.scope}}.as_rate()"
        aggregator = "avg"
      }
    }
  }

  widget {
    widget_layout {
      x      = 4
      y      = 0
      width  = 4
      height = 2
    }

    query_value_definition {
      title       = "Error rate (%)"
      precision   = 2
      custom_unit = "%"

      request {
        q          = "( sum:trace.${var.operation}.errors{${local.scope}}.as_count() / sum:trace.${var.operation}.hits{${local.scope}}.as_count() ) * 100"
        aggregator = "avg"

        conditional_formats {
          comparator = ">"
          value      = 5
          palette    = "white_on_red"
        }

        conditional_formats {
          comparator = ">"
          value      = 2
          palette    = "white_on_yellow"
        }

        conditional_formats {
          comparator = "<="
          value      = 2
          palette    = "white_on_green"
        }
      }
    }
  }

  widget {
    widget_layout {
      x      = 8
      y      = 0
      width  = 4
      height = 2
    }

    query_value_definition {
      title     = "p95 latency"
      autoscale = true
      precision = 2

      request {
        q          = "p95:trace.${var.operation}{${local.scope}}"
        aggregator = "avg"
      }
    }
  }

  widget {
    widget_layout {
      x      = 0
      y      = 2
      width  = 6
      height = 3
    }

    timeseries_definition {
      title       = "Requests and errors"
      show_legend = true

      request {
        q            = "sum:trace.${var.operation}.hits{${local.scope}}.as_count()"
        display_type = "bars"

        style {
          palette = "cool"
        }
      }

      request {
        q            = "sum:trace.${var.operation}.errors{${local.scope}}.as_count()"
        display_type = "bars"

        style {
          palette = "warm"
        }
      }
    }
  }

  widget {
    widget_layout {
      x      = 6
      y      = 2
      width  = 6
      height = 3
    }

    timeseries_definition {
      title       = "Latency percentiles"
      show_legend = true

      request {
        q            = "p50:trace.${var.operation}{${local.scope}}"
        display_type = "line"
      }

      request {
        q            = "p95:trace.${var.operation}{${local.scope}}"
        display_type = "line"
      }

      request {
        q            = "p99:trace.${var.operation}{${local.scope}}"
        display_type = "line"
      }
    }
  }

  widget {
    widget_layout {
      x      = 0
      y      = 5
      width  = 6
      height = 3
    }

    timeseries_definition {
      title       = "Container CPU by pod"
      show_legend = false

      request {
        q            = "avg:kubernetes.cpu.usage.total{kube_deployment:${var.service},$env} by {pod_name}"
        display_type = "line"
      }
    }
  }

  widget {
    widget_layout {
      x      = 6
      y      = 5
      width  = 6
      height = 3
    }

    timeseries_definition {
      title       = "Container memory by pod"
      show_legend = false

      request {
        q            = "avg:kubernetes.memory.usage{kube_deployment:${var.service},$env} by {pod_name}"
        display_type = "line"
      }
    }
  }

  dynamic "widget" {
    for_each = var.slo_id == null ? [] : [var.slo_id]

    content {
      widget_layout {
        x      = 0
        y      = 8
        width  = 12
        height = 3
      }

      service_level_objective_definition {
        title             = "Availability SLO (prod)"
        view_type         = "detail"
        slo_id            = widget.value
        show_error_budget = true
        view_mode         = "overall"
        time_windows      = ["7d", "30d"]
      }
    }
  }
}
