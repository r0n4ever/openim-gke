# Development environment configuration for OpenIM GKE deployment
# This file contains all configurable variables for the infrastructure and application

# ==============================================================================
# GCP Project Configuration
# ==============================================================================
project_id = "your-gcp-project-id"  # TODO: Replace with your GCP project ID
region     = "us-central1"           # GCP region for cluster deployment
environment = "dev"

# ==============================================================================
# GKE Cluster Configuration
# ==============================================================================
cluster_name = "openim-dev-cluster"

# Network settings
create_network   = true
network_name     = "openim-dev-network"
subnetwork_name  = "openim-dev-subnetwork"
subnetwork_cidr  = "10.0.0.0/20"
cluster_ipv4_cidr   = "10.4.0.0/14"  # Pod IP range
services_ipv4_cidr  = "10.8.0.0/20"  # Service IP range

# ==============================================================================
# Node Pool Configuration
# ==============================================================================
# Node count settings
node_count     = 3    # Initial number of nodes
min_node_count = 2    # Minimum for autoscaling
max_node_count = 10   # Maximum for autoscaling

# Node specifications
machine_type      = "e2-standard-4"  # 4 vCPU, 16 GB RAM
disk_size_gb      = 100              # Disk size per node
disk_type         = "pd-standard"    # Options: pd-standard, pd-ssd
preemptible_nodes = false            # Set to true for cost savings (not for production)
auto_upgrade_nodes = true            # Enable automatic security updates

# Node labels and tags
node_labels = {
  workload = "openim"
  tier     = "application"
}
node_tags = ["openim", "dev"]

# ==============================================================================
# Maintenance Configuration
# ==============================================================================
maintenance_window = "03:00"  # Daily maintenance window (UTC)

# ==============================================================================
# Helm Values Override (referenced in helm installations)
# ==============================================================================
# These can be used to override Helm chart values via CLI or scripts

# Ingress NGINX
# ingress_nginx_version = "4.9.0"

# Redpanda (Kafka replacement)
# redpanda_replicas = 3
# redpanda_storage_size = "10Gi"

# Dragonfly (Redis replacement)
# dragonfly_replicas = 2
# dragonfly_memory_limit = "2Gi"

# SeaweedFS (MinIO replacement)
# seaweedfs_master_replicas = 3
# seaweedfs_volume_replicas = 3
# seaweedfs_storage_size = "50Gi"

# OpenIM Application
# openim_replicas = 2
# openim_domain = "openim.example.com"  # TODO: Replace with your domain

# ==============================================================================
# Notes:
# - Adjust machine_type and node_count based on your workload requirements
# - For production, set preemptible_nodes = false and increase min_node_count
# - Update project_id before running terraform/tofu commands
# - All Helm component configurations are in their respective values.yaml files
# ==============================================================================
