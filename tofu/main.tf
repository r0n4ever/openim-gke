# Main Terraform/OpenTofu configuration for GKE cluster
# This file creates a GKE cluster for OpenIM deployment

# GKE Cluster
resource "google_container_cluster" "openim_cluster" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool and create custom one
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr
    services_ipv4_cidr_block = var.services_ipv4_cidr
  }

  # Master auth configuration
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Cluster features
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_window
    }
  }
}

# Separately managed node pool
resource "google_container_node_pool" "openim_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.openim_cluster.name
  node_count = var.node_count

  # Auto-scaling configuration
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Node configuration
  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = merge(
      var.node_labels,
      {
        environment = var.environment
        managed_by  = "terraform"
      }
    )

    # Tags
    tags = var.node_tags

    # Workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Upgrade settings
  management {
    auto_repair  = true
    auto_upgrade = var.auto_upgrade_nodes
  }
}

# VPC Network (if not existing)
resource "google_compute_network" "openim_network" {
  count                   = var.create_network ? 1 : 0
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnetwork (if not existing)
resource "google_compute_subnetwork" "openim_subnetwork" {
  count         = var.create_network ? 1 : 0
  name          = var.subnetwork_name
  ip_cidr_range = var.subnetwork_cidr
  region        = var.region
  network       = google_compute_network.openim_network[0].id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.cluster_ipv4_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_ipv4_cidr
  }
}
