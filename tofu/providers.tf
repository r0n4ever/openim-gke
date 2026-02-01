# OpenIM GKE 基础设施提供者配置

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"  # 更新到最新稳定版本
    }
  }

  # 后端配置（取消注释并配置用于远程状态）
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "openim/gke"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
