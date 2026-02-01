# Provider configuration for OpenIM GKE infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configuration (uncomment and configure for remote state)
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "openim/gke"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
