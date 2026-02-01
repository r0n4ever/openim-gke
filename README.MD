# OpenIM on GKE - One-Click Deployment

一键部署 OpenIM 到 Google Kubernetes Engine (GKE) 的完整解决方案，使用 OpenTofu/Terraform + Helm，采用高性能组件替换方案。

Deploy OpenIM to Google Kubernetes Engine (GKE) with a single command, using OpenTofu/Terraform + Helm with high-performance component replacements.

## 🎯 Project Overview / 项目概述

This project provides a production-ready, one-click deployment solution for OpenIM on GKE with the following architecture:

本项目提供了一个生产就绪的 OpenIM on GKE 一键部署方案，具有以下架构：

### Component Replacements / 组件替换

| Standard Component | Replacement | Reason / 原因 |
|-------------------|-------------|--------------|
| **Kafka** | **Redpanda** | Simpler, faster, Kafka API compatible / 更简单、更快、Kafka API 兼容 |
| **Redis** | **Dragonfly** | 25x faster, Redis protocol compatible / 25倍速度提升、Redis 协议兼容 |
| **MinIO** | **SeaweedFS** | Better for small files, S3 API compatible / 小文件性能更好、S3 API 兼容 |
| **MySQL** | **MySQL** | Official chart / 官方 chart |

**Key Principle / 核心原则**: **NO CODE CHANGES REQUIRED** - All replacements use standard APIs / 无需修改 OpenIM 代码 - 所有替换使用标准 API

## 📁 Directory Structure / 目录结构

```
openim-gke/
├── tofu/                           # OpenTofu/Terraform infrastructure code
│   ├── main.tf                     # GKE cluster configuration
│   ├── variables.tf                # Configurable parameters
│   ├── outputs.tf                  # Cluster outputs (kubeconfig)
│   └── providers.tf                # GCP provider configuration
│
├── helm/                           # Helm charts for all components (numbered for installation order)
│   ├── 10-ingress-nginx/          # NGINX Ingress Controller
│   │   ├── values.yaml            # Ingress configuration
│   │   └── README.md              # Installation guide
│   │
│   ├── 20-redpanda/               # Redpanda (Kafka replacement)
│   │   ├── values.yaml            # Redpanda configuration
│   │   └── README.md              # Installation & troubleshooting
│   │
│   ├── 30-dragonfly/              # Dragonfly (Redis replacement)
│   │   ├── Chart.yaml             # Custom minimal Helm chart
│   │   ├── values.yaml            # Dragonfly configuration
│   │   ├── templates/             # Kubernetes manifests
│   │   └── README.md              # Installation & troubleshooting
│   │
│   ├── 40-seaweedfs/              # SeaweedFS (MinIO replacement)
│   │   ├── values.yaml            # SeaweedFS configuration
│   │   └── README.md              # Installation & troubleshooting
│   │
│   └── 90-openim/                 # OpenIM Server Application
│       ├── values.yaml            # OpenIM with all integrations
│       └── README.md              # Complete deployment guide
│
├── envs/                           # Environment configuration
│   └── dev.tfvars                 # Development environment variables
│
├── .gitignore                      # Git ignore file
└── README.md                       # This file (main entry point)
```

## 🚀 Quick Start / 快速开始

### Prerequisites / 前置条件

1. **GCP Account** with billing enabled / GCP 账号并启用计费
2. **gcloud CLI** installed and configured / 安装并配置 gcloud CLI
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```
3. **kubectl** installed / 安装 kubectl
4. **Helm 3** installed / 安装 Helm 3
5. **OpenTofu** or **Terraform** installed / 安装 OpenTofu 或 Terraform
   ```bash
   # Install OpenTofu (recommended)
   curl -Lo tofu.tar.gz https://github.com/opentofu/opentofu/releases/latest/download/tofu_*_linux_amd64.tar.gz
   tar -xzf tofu.tar.gz && sudo mv tofu /usr/local/bin/
   
   # Or install Terraform
   # wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   # unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/
   ```

### Installation Steps / 安装步骤

#### Step 1: Configure Variables / 配置变量

Edit `envs/dev.tfvars` with your GCP project settings:

编辑 `envs/dev.tfvars` 填入你的 GCP 项目设置：

```bash
# Required: Replace with your GCP project ID
project_id = "your-gcp-project-id"

# Optional: Adjust these based on your needs
region         = "us-central1"
cluster_name   = "openim-dev-cluster"
node_count     = 3
machine_type   = "e2-standard-4"
```

#### Step 2: Deploy Infrastructure / 部署基础设施

```bash
cd tofu/

# Initialize Terraform/OpenTofu
tofu init  # or: terraform init

# Review the execution plan
tofu plan -var-file=../envs/dev.tfvars

# Apply the configuration (create GKE cluster)
tofu apply -var-file=../envs/dev.tfvars

# Configure kubectl to use the new cluster
gcloud container clusters get-credentials openim-dev-cluster \
  --region us-central1 \
  --project your-gcp-project-id
```

**⏱️ Time:** ~10-15 minutes for GKE cluster creation / GKE 集群创建需要 10-15 分钟

#### Step 3: Deploy Components with Helm / 使用 Helm 部署组件

**Important:** Install components in order (numbered directories) / 重要：按顺序安装组件（编号目录）

```bash
# 1. Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --values helm/10-ingress-nginx/values.yaml

# Wait for external IP
kubectl get svc -n ingress-nginx -w

# 2. Install Redpanda (Kafka replacement)
helm repo add redpanda https://charts.redpanda.com
helm repo update
helm install redpanda redpanda/redpanda \
  --namespace redpanda --create-namespace \
  --values helm/20-redpanda/values.yaml

# Wait for Redpanda to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redpanda -n redpanda --timeout=300s

# 3. Install Dragonfly (Redis replacement)
helm install dragonfly helm/30-dragonfly \
  --namespace dragonfly --create-namespace

# Wait for Dragonfly to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dragonfly -n dragonfly --timeout=300s

# 4. Install SeaweedFS (MinIO replacement)
helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
helm repo update
helm install seaweedfs seaweedfs/seaweedfs \
  --namespace seaweedfs --create-namespace \
  --values helm/40-seaweedfs/values.yaml

# Wait for SeaweedFS to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=master -n seaweedfs --timeout=300s

# Create S3 bucket for OpenIM
kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333 &
aws --endpoint-url http://localhost:8333 s3 mb s3://openim

# 5. Install OpenIM Server
helm repo add openim https://openimsdk.github.io/helm-charts
helm repo update
helm install openim openim/openim-server \
  --namespace openim --create-namespace \
  --values helm/90-openim/values.yaml

# Wait for OpenIM to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=openim -n openim --timeout=600s
```

**⏱️ Time:** ~15-20 minutes for all components / 所有组件部署需要 15-20 分钟

**Total deployment time:** ~30 minutes from start to finish / 从开始到结束总共约 30 分钟

## ✅ Verification Checklist / 验证清单

Use this checklist to verify your deployment:

使用此清单验证您的部署：

### Infrastructure / 基础设施

```bash
# Check cluster status
kubectl get nodes
kubectl cluster-info

# Check storage classes
kubectl get storageclass
```

- [ ] GKE cluster is running / GKE 集群运行中
- [ ] All nodes are Ready / 所有节点就绪
- [ ] Storage class available / 存储类可用

### Components / 组件

```bash
# Check all namespaces
kubectl get pods --all-namespaces

# Or check each component
kubectl get pods -n ingress-nginx
kubectl get pods -n redpanda
kubectl get pods -n dragonfly
kubectl get pods -n seaweedfs
kubectl get pods -n openim
```

- [ ] Ingress NGINX running with external IP / Ingress NGINX 运行并有外部 IP
- [ ] Redpanda cluster healthy (3/3 pods) / Redpanda 集群健康（3/3 pods）
- [ ] Dragonfly running (2/2 pods) / Dragonfly 运行（2/2 pods）
- [ ] SeaweedFS all components running / SeaweedFS 所有组件运行
- [ ] OpenIM all pods running / OpenIM 所有 pods 运行

### Connectivity / 连通性

```bash
# Test Redpanda (Kafka)
kubectl exec -it redpanda-0 -n redpanda -- rpk cluster info

# Test Dragonfly (Redis)
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping

# Test SeaweedFS (S3)
kubectl run s3-test --rm -it --restart=Never --image=amazon/aws-cli -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  s3 ls

# Test OpenIM API
kubectl port-forward -n openim svc/openim-api 10002:10002
curl http://localhost:10002/health
```

- [ ] Redpanda accepts Kafka connections / Redpanda 接受 Kafka 连接
- [ ] Dragonfly accepts Redis connections / Dragonfly 接受 Redis 连接
- [ ] SeaweedFS S3 API accessible / SeaweedFS S3 API 可访问
- [ ] OpenIM API responds / OpenIM API 响应

### API Testing / API 测试

```bash
# Port-forward OpenIM API
kubectl port-forward -n openim svc/openim-api 10002:10002

# Test health
curl http://localhost:10002/health

# Test version
curl http://localhost:10002/version
```

- [ ] Health check returns 200 / 健康检查返回 200
- [ ] Version endpoint works / 版本端点工作
- [ ] User registration works / 用户注册工作
- [ ] User login works / 用户登录工作

### WebSocket Testing / WebSocket 测试

```bash
# Port-forward message gateway
kubectl port-forward -n openim svc/openim-msggateway 10001:10001

# Test with websocat (install if needed: apt-get install websocat)
echo '{"type":"ping"}' | websocat ws://localhost:10001/ws
```

- [ ] WebSocket connection establishes / WebSocket 连接建立
- [ ] Messages can be sent / 消息可以发送
- [ ] Real-time delivery works / 实时投递工作

### Storage Testing / 存储测试

```bash
# Upload a test file via OpenIM API
# This tests the SeaweedFS integration
# (Use OpenIM client or API documentation for specific endpoints)
```

- [ ] File upload works / 文件上传工作
- [ ] Files stored in SeaweedFS / 文件存储在 SeaweedFS
- [ ] Files can be retrieved / 文件可以检索

### Logs and Observability / 日志和可观测性

```bash
# Check logs for each component
kubectl logs -n openim -l app=openim-api --tail=50
kubectl logs -n redpanda redpanda-0 --tail=50
kubectl logs -n dragonfly dragonfly-0 --tail=50
kubectl logs -n seaweedfs -l app.kubernetes.io/component=filer --tail=50
```

- [ ] No error messages in logs / 日志中无错误消息
- [ ] Metrics endpoints accessible / 指标端点可访问
- [ ] All components reporting healthy / 所有组件报告健康

## 🔧 Configuration Guide / 配置指南

### Single Entry Point / 单一入口

All configuration starts from `envs/dev.tfvars`:

所有配置从 `envs/dev.tfvars` 开始：

```hcl
# Infrastructure settings
project_id   = "your-project"
region       = "us-central1"
cluster_name = "openim-dev"

# Node pool settings
node_count     = 3      # Initial nodes
min_node_count = 2      # Minimum for autoscaling
max_node_count = 10     # Maximum for autoscaling
machine_type   = "e2-standard-4"  # 4 vCPU, 16GB RAM

# For production, adjust:
# - machine_type to "e2-standard-8" or larger
# - node_count to at least 5
# - min_node_count to 3
```

### Adjusting Resources / 调整资源

**For Development / 开发环境:**
- machine_type: `e2-standard-4` (4 vCPU, 16GB)
- node_count: 3
- Total: ~50 GB RAM, 12 vCPU

**For Production / 生产环境:**
- machine_type: `e2-standard-8` (8 vCPU, 32GB)
- node_count: 5
- Total: ~160 GB RAM, 40 vCPU

### Component-Specific Configuration / 组件特定配置

Each component has its own `values.yaml`:

每个组件都有自己的 `values.yaml`：

- **Redpanda** (`helm/20-redpanda/values.yaml`): Adjust replicas, storage size
- **Dragonfly** (`helm/30-dragonfly/values.yaml`): Adjust memory limits
- **SeaweedFS** (`helm/40-seaweedfs/values.yaml`): Adjust volume storage size
- **OpenIM** (`helm/90-openim/values.yaml`): Adjust all service replicas

## 📊 Component Comparison / 组件对比

### Advantages of Replacements / 替换方案的优势

#### Redpanda vs Kafka

| Feature | Kafka | Redpanda |
|---------|-------|----------|
| Architecture | Requires ZooKeeper | Single binary |
| Setup Complexity | High | Low |
| Resource Usage | High (JVM) | Low (C++) |
| Performance | Good | Excellent |
| Kafka Compatibility | 100% | 100% |
| Operational Overhead | High | Low |

**Pros / 优点:**
- 10x faster topic creation / 10倍速度创建 topic
- 5x lower latency / 5倍降低延迟
- 30% less memory / 30% 更少内存
- No ZooKeeper dependency / 无 ZooKeeper 依赖

**Cons / 缺点:**
- Newer technology / 较新技术
- Smaller ecosystem / 较小生态

#### Dragonfly vs Redis

| Feature | Redis | Dragonfly |
|---------|-------|-----------|
| Threading | Single-threaded | Multi-threaded |
| Performance | Baseline | 25x faster |
| Memory Usage | Baseline | 30% less |
| Redis Compatibility | 100% | ~95% |
| Vertical Scaling | Limited | Excellent |

**Pros / 优点:**
- 25x better throughput / 25倍吞吐量提升
- Multi-core utilization / 多核利用
- Lower memory footprint / 更小内存占用
- Built-in snapshots / 内置快照

**Cons / 缺点:**
- Not 100% Redis compatible / 不是 100% Redis 兼容
- Newer project / 较新项目

#### SeaweedFS vs MinIO

| Feature | MinIO | SeaweedFS |
|---------|-------|-----------|
| Architecture | Distributed locks | Simpler |
| Small Files | Good | Excellent |
| Large Files | Excellent | Good |
| S3 Compatibility | ~100% | ~99% |
| Resource Usage | Moderate | Low |

**Pros / 优点:**
- Better for many small files / 更适合大量小文件
- Simpler architecture / 更简单架构
- Lower resource usage / 更低资源使用
- Native file system support / 原生文件系统支持

**Cons / 缺点:**
- Fewer S3 features / 更少 S3 功能
- Smaller ecosystem / 较小生态

### When NOT to Use Replacements / 何时不使用替换方案

Consider using standard components if:

如果符合以下条件，考虑使用标准组件：

- **Very large scale** (100+ brokers for Kafka) / 超大规模
- **Need 100% compatibility** with all Redis/S3 features / 需要 100% 兼容性
- **Large existing ecosystem integration** / 大量现有生态系统集成
- **Risk-averse production environment** / 风险规避的生产环境

## 🔄 Upgrade and Failover / 升级和故障切换

### Upgrading Components / 升级组件

```bash
# Update Helm repositories
helm repo update

# Upgrade a specific component (example: Redpanda)
helm upgrade redpanda redpanda/redpanda \
  --namespace redpanda \
  --values helm/20-redpanda/values.yaml

# Check upgrade status
helm status redpanda -n redpanda

# Rollback if needed
helm rollback redpanda -n redpanda
```

### Failover Procedures / 故障切换程序

#### Database Failover / 数据库故障切换

If using MySQL replication:

如果使用 MySQL 复制：

```bash
# Promote a replica to primary
kubectl exec -it mysql-secondary-0 -n openim -- mysql -u root -p
# Execute: STOP SLAVE; RESET SLAVE ALL;

# Update OpenIM configuration to point to new primary
helm upgrade openim openim/openim-server \
  --namespace openim \
  --set mysql.external.host=mysql-secondary.openim.svc.cluster.local
```

#### Redpanda Failover / Redpanda 故障切换

Redpanda has built-in HA with 3 replicas:

Redpanda 内置高可用，3个副本：

```bash
# Check cluster status
kubectl exec -it redpanda-0 -n redpanda -- rpk cluster info

# Redpanda automatically elects new leaders
# No manual intervention needed
```

#### Dragonfly Failover / Dragonfly 故障切换

```bash
# Dragonfly StatefulSet automatically restarts failed pods
# Data is persisted to PVs and restored on restart

# Check pod status
kubectl get pods -n dragonfly

# If needed, manually restart
kubectl rollout restart statefulset dragonfly -n dragonfly
```

## 🛠️ Troubleshooting / 故障排查

### Common Issues / 常见问题

#### Issue 1: GKE Cluster Creation Fails / GKE 集群创建失败

```bash
# Check quota limits
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Check service APIs are enabled
gcloud services list --enabled --project=YOUR_PROJECT_ID
```

**Solution / 解决方案:**
- Enable required APIs: `gcloud services enable container.googleapis.com`
- Request quota increase if needed / 如需要，请求配额增加

#### Issue 2: Pods Stuck in Pending / Pods 卡在 Pending

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
```

**Solution / 解决方案:**
- Increase node count: Update `envs/dev.tfvars` and re-apply / 增加节点数
- Use larger machine type / 使用更大的机器类型

#### Issue 3: Connection Refused Between Components / 组件间连接被拒

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup redpanda.redpanda.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv redpanda.redpanda.svc.cluster.local 9092
```

**Solution / 解决方案:**
- Verify service names in `values.yaml` / 验证 values.yaml 中的服务名
- Check network policies / 检查网络策略
- Ensure components are in Running state / 确保组件处于运行状态

#### Issue 4: Ingress Not Getting External IP / Ingress 未获取外部 IP

```bash
# Check ingress controller service
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'
```

**Solution / 解决方案:**
- Wait 5-10 minutes for GCP Load Balancer creation / 等待 5-10 分钟让 GCP 负载均衡器创建
- Check GCP quotas for load balancers / 检查 GCP 负载均衡器配额

### Debug Commands / 调试命令

```bash
# View logs
kubectl logs -n <namespace> <pod-name> --tail=100 -f

# Execute commands in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Check resource usage
kubectl top pods -n <namespace>
kubectl top nodes

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Describe resource
kubectl describe <resource-type> <resource-name> -n <namespace>
```

## 🔐 Security Considerations / 安全考虑

### Default Credentials (MUST CHANGE) / 默认凭证（必须更改）

The following default credentials are used and **MUST BE CHANGED** in production:

以下默认凭证必须在生产环境中更改：

| Component | Default Credentials | Location |
|-----------|---------------------|----------|
| MySQL | root: `openIM123`, user: `openIM/openIM123` | `helm/90-openim/values.yaml` |
| SeaweedFS S3 | Access: `admin`, Secret: `admin123` | `helm/40-seaweedfs/values.yaml` |
| Redpanda | No auth (internal only) | Enable SASL for production |
| Dragonfly | No auth (internal only) | Enable password for production |

### Security Hardening / 安全加固

1. **Enable TLS/SSL** for all external endpoints / 为所有外部端点启用 TLS/SSL
2. **Network Policies** to restrict pod-to-pod communication / 网络策略限制 pod 间通信
3. **RBAC** for Kubernetes access control / RBAC 进行 Kubernetes 访问控制
4. **Pod Security Policies** / Pod 安全策略
5. **Secrets Management** using Google Secret Manager or HashiCorp Vault / 使用 Google Secret Manager 或 HashiCorp Vault 管理密钥

## 📝 TODOs and Customization / 待办事项和自定义

### Before Production / 生产前必做

- [ ] **Change all default passwords** / 更改所有默认密码
- [ ] **Configure actual domain name** / 配置实际域名
- [ ] **Enable TLS with cert-manager** / 使用 cert-manager 启用 TLS
- [ ] **Enable authentication** for Redpanda and Dragonfly / 为 Redpanda 和 Dragonfly 启用认证
- [ ] **Set up monitoring** (Prometheus + Grafana) / 设置监控
- [ ] **Configure alerting** / 配置告警
- [ ] **Set up backup strategy** / 设置备份策略
- [ ] **Document runbooks** / 文档化运维手册
- [ ] **Load testing** / 负载测试
- [ ] **Security audit** / 安全审计

### Optional Enhancements / 可选增强

- [ ] **Multi-region deployment** / 多区域部署
- [ ] **Disaster recovery plan** / 灾难恢复计划
- [ ] **CI/CD pipeline** / CI/CD 流水线
- [ ] **Service mesh** (Istio/Linkerd) / 服务网格
- [ ] **Advanced monitoring** (Elastic Stack) / 高级监控
- [ ] **Cost optimization** / 成本优化

### Known Limitations / 已知限制

1. **OpenIM Helm Chart Compatibility**: This configuration is based on the OpenIM Helm chart structure. If the official chart changes fields, update `helm/90-openim/values.yaml` accordingly.
   
   OpenIM Helm Chart 兼容性：此配置基于 OpenIM Helm chart 结构。如果官方 chart 更改字段，请相应更新 values.yaml。

2. **Dragonfly Helm Chart**: We provide a minimal custom chart as there's no mature official Helm chart. Update if official chart becomes available.
   
   Dragonfly Helm Chart：我们提供了一个最小的自定义 chart，因为没有成熟的官方 Helm chart。如果官方 chart 可用，请更新。

3. **SeaweedFS S3 Compatibility**: ~99% compatible, some advanced S3 features may not work.
   
   SeaweedFS S3 兼容性：约 99% 兼容，某些高级 S3 功能可能不工作。

4. **PostgreSQL Support**: Not officially supported by OpenIM. Requires custom configuration and testing.
   
   PostgreSQL 支持：OpenIM 官方不支持。需要自定义配置和测试。

## 🔗 Useful Links / 有用链接

### Official Documentation / 官方文档

- **OpenIM**: https://github.com/openimsdk/open-im-server
- **OpenIM Helm Charts**: https://github.com/openimsdk/helm-charts
- **Redpanda**: https://docs.redpanda.com/
- **Dragonfly**: https://www.dragonflydb.io/docs
- **SeaweedFS**: https://github.com/seaweedfs/seaweedfs/wiki
- **GKE**: https://cloud.google.com/kubernetes-engine/docs

### Tools / 工具

- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **Helm**: https://helm.sh/docs/
- **OpenTofu**: https://opentofu.org/docs/
- **gcloud CLI**: https://cloud.google.com/sdk/docs/install

## 🤝 Contributing / 贡献

Contributions are welcome! Please:

欢迎贡献！请：

1. Fork this repository / Fork 此仓库
2. Create a feature branch / 创建功能分支
3. Make your changes / 进行更改
4. Test thoroughly / 彻底测试
5. Submit a pull request / 提交 pull request

## 📄 License / 许可证

This project is provided as-is for deploying OpenIM on GKE. Please refer to the individual components for their respective licenses.

此项目按原样提供用于在 GKE 上部署 OpenIM。请参考各个组件的相应许可证。

## 💬 Support / 支持

For issues and questions:

问题和疑问：

1. Check component READMEs in `helm/*/README.md` / 检查 helm/*/README.md 中的组件 README
2. Review troubleshooting section above / 查看上面的故障排查部分
3. Open an issue in this repository / 在此仓库中开启 issue
4. Consult official documentation for each component / 查阅每个组件的官方文档

---

**Ready to deploy? Start with Step 1 above! / 准备部署？从上面的步骤 1 开始！**

**Questions? Check the detailed README in each `helm/*/` directory! / 有疑问？查看每个 helm/*/ 目录中的详细 README！**
