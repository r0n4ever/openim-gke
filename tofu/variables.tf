# OpenIM GKE 基础设施变量

variable "project_id" {
  description = "GCP 项目 ID"
  type        = string
}

variable "region" {
  description = "GKE 集群的 GCP 区域"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE 集群名称"
  type        = string
  default     = "openim-cluster"
}

variable "environment" {
  description = "环境名称（dev、staging、prod）"
  type        = string
  default     = "dev"
}

# 网络配置
variable "create_network" {
  description = "是否创建新的 VPC 网络"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "VPC 网络名称"
  type        = string
  default     = "openim-network"
}

variable "subnetwork_name" {
  description = "子网名称"
  type        = string
  default     = "openim-subnetwork"
}

variable "subnetwork_cidr" {
  description = "子网的 CIDR 范围"
  type        = string
  default     = "10.0.0.0/20"
}

variable "cluster_ipv4_cidr" {
  description = "集群 Pod 的 CIDR 范围"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_ipv4_cidr" {
  description = "集群服务的 CIDR 范围"
  type        = string
  default     = "10.8.0.0/20"
}

# 节点池配置
variable "node_count" {
  description = "节点池中节点的初始数量"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "自动扩缩容的最小节点数"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "自动扩缩容的最大节点数"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "节点的机器类型"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "节点磁盘大小（GB）"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "节点磁盘类型"
  type        = string
  default     = "pd-standard"
}

variable "preemptible_nodes" {
  description = "使用可抢占节点（不建议用于生产环境）"
  type        = bool
  default     = false
}

variable "auto_upgrade_nodes" {
  description = "启用自动节点升级"
  type        = bool
  default     = true
}

variable "node_labels" {
  description = "应用于节点的标签"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "应用于节点的网络标签"
  type        = list(string)
  default     = ["openim"]
}

# 维护
variable "maintenance_window" {
  description = "每日维护窗口开始时间（HH:MM）"
  type        = string
  default     = "03:00"
}
