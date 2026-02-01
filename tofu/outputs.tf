# OpenIM GKE 基础设施输出

output "cluster_name" {
  description = "GKE 集群名称"
  value       = google_container_cluster.openim_cluster.name
}

output "cluster_endpoint" {
  description = "GKE 集群端点"
  value       = google_container_cluster.openim_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE 集群 CA 证书"
  value       = google_container_cluster.openim_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "region" {
  description = "GCP 区域"
  value       = var.region
}

output "project_id" {
  description = "GCP 项目 ID"
  value       = var.project_id
}

# Kubeconfig 生成命令
output "kubeconfig_command" {
  description = "配置 kubectl 的命令"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.openim_cluster.name} --region ${var.region} --project ${var.project_id}"
}

# 网络信息
output "network_name" {
  description = "VPC 网络名称"
  value       = var.network_name
}

output "subnetwork_name" {
  description = "子网名称"
  value       = var.subnetwork_name
}
