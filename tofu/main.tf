# GKE 集群的主 Terraform/OpenTofu 配置
# 此文件创建用于 OpenIM 部署的 GKE 集群

# GKE 集群
resource "google_container_cluster" "openim_cluster" {
  name     = var.cluster_name
  location = var.region

  # 移除默认节点池并创建自定义节点池
  remove_default_node_pool = true
  initial_node_count       = 1

  # 网络配置
  network    = var.network_name
  subnetwork = var.subnetwork_name

  # VPC 原生集群的 IP 分配策略
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.cluster_ipv4_cidr
    services_ipv4_cidr_block = var.services_ipv4_cidr
  }

  # Master 认证配置
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # 集群功能
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # 启用工作负载身份
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 维护窗口
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_window
    }
  }
}

# 单独管理的节点池
resource "google_container_node_pool" "openim_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.openim_cluster.name
  node_count = var.node_count

  # 自动扩缩容配置
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # 节点配置
  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # OAuth 作用域
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # 标签
    labels = merge(
      var.node_labels,
      {
        environment = var.environment
        managed_by  = "terraform"
      }
    )

    # 标签
    tags = var.node_tags

    # 工作负载身份
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # 元数据
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # 升级设置
  management {
    auto_repair  = true
    auto_upgrade = var.auto_upgrade_nodes
  }
}

# VPC 网络（如果不存在）
resource "google_compute_network" "openim_network" {
  count                   = var.create_network ? 1 : 0
  name                    = var.network_name
  auto_create_subnetworks = false
}

# 子网（如果不存在）
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
