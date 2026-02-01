# Variables for OpenIM GKE infrastructure

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "openim-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Network configuration
variable "create_network" {
  description = "Whether to create a new VPC network"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "openim-network"
}

variable "subnetwork_name" {
  description = "Name of the subnetwork"
  type        = string
  default     = "openim-subnetwork"
}

variable "subnetwork_cidr" {
  description = "CIDR range for the subnetwork"
  type        = string
  default     = "10.0.0.0/20"
}

variable "cluster_ipv4_cidr" {
  description = "CIDR range for cluster pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_ipv4_cidr" {
  description = "CIDR range for cluster services"
  type        = string
  default     = "10.8.0.0/20"
}

# Node pool configuration
variable "node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Disk size in GB for nodes"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type for nodes"
  type        = string
  default     = "pd-standard"
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes (not recommended for production)"
  type        = bool
  default     = false
}

variable "auto_upgrade_nodes" {
  description = "Enable automatic node upgrades"
  type        = bool
  default     = true
}

variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "Network tags to apply to nodes"
  type        = list(string)
  default     = ["openim"]
}

# Maintenance
variable "maintenance_window" {
  description = "Daily maintenance window start time (HH:MM)"
  type        = string
  default     = "03:00"
}
