terraform {
  required_version = ">= 1.10"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

# Credentials come from DD_API_KEY and DD_APP_KEY in the environment, so they
# never appear in variables, tfvars or plan output.
provider "datadog" {
  api_url = var.datadog_api_url
}
