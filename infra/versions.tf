terraform {
  required_version = "~> 1.12"

  # Explicit local backend avoids the deprecated -state CLI flag that azd passes.
  # azd copies infra/ to .azure/<env>/infra/ and runs terraform there, so
  # "terraform.tfstate" in the working directory matches azd's expected path.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
