# Outputs for OpenIM GKE infrastructure

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.openim_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.openim_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.openim_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

# Kubeconfig generation command
output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.openim_cluster.name} --region ${var.region} --project ${var.project_id}"
}

# Network information
output "network_name" {
  description = "VPC network name"
  value       = var.network_name
}

output "subnetwork_name" {
  description = "Subnetwork name"
  value       = var.subnetwork_name
}
