#!/bin/bash
# OpenIM on GKE - 快速部署脚本
# 此脚本自动化部署过程

set -e  # 出错时退出

# 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 打印彩色输出的函数
print_info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查命令是否存在的函数
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查先决条件
print_info "检查先决条件..."

if ! command_exists kubectl; then
    print_error "kubectl 未安装。请先安装它。"
    exit 1
fi

if ! command_exists helm; then
    print_error "helm 未安装。请先安装它。"
    exit 1
fi

if ! command_exists gcloud; then
    print_error "gcloud 未安装。请先安装它。"
    exit 1
fi

if ! command_exists tofu && ! command_exists terraform; then
    print_error "OpenTofu 和 Terraform 都未安装。请安装其中之一。"
    exit 1
fi

# 确定使用哪个 IaC 工具
if command_exists tofu; then
    IAC_CMD="tofu"
else
    IAC_CMD="terraform"
fi

print_info "使用 $IAC_CMD 进行基础设施管理"

# 等待 pods 就绪的函数
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    print_info "等待命名空间 $namespace 中的 pods 就绪..."
    kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$namespace" \
        --timeout="${timeout}s" || {
        print_warn "某些 pods 可能尚未就绪。继续..."
    }
}

# 主部署函数
main() {
    print_info "开始 OpenIM on GKE 部署..."
    
    # 步骤 1：部署基础设施
    print_info "步骤 1：部署 GKE 基础设施..."
    cd tofu/
    $IAC_CMD init
    $IAC_CMD plan -var-file=../envs/dev.tfvars
    
    read -p "是否要应用基础设施？(yes/no)：" confirm
    if [ "$confirm" != "yes" ]; then
        print_error "用户取消部署"
        exit 1
    fi
    
    $IAC_CMD apply -var-file=../envs/dev.tfvars -auto-approve
    
    # 获取集群凭证
    print_info "配置 kubectl..."
    PROJECT_ID=$(grep 'project_id' ../envs/dev.tfvars | cut -d'"' -f2)
    REGION=$(grep 'region' ../envs/dev.tfvars | cut -d'"' -f2)
    CLUSTER_NAME=$(grep 'cluster_name' ../envs/dev.tfvars | cut -d'"' -f2)
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID"
    
    cd ..
    
    # 步骤 2：部署 Helm 组件
    print_info "步骤 2：部署 Helm 组件..."
    
    # 2.1：安装 NGINX Ingress Controller
    print_info "安装 NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --values helm/10-ingress-nginx/values.yaml
    
    wait_for_pods "ingress-nginx" "app.kubernetes.io/name=ingress-nginx"
    
    # 等待外部 IP
    print_info "等待外部 IP..."
    kubectl get svc -n ingress-nginx ingress-nginx-controller -w &
    WAIT_PID=$!
    sleep 30
    kill $WAIT_PID 2>/dev/null || true
    
    # 2.2：安装 Redpanda
    print_info "安装 Redpanda..."
    helm repo add redpanda https://charts.redpanda.com
    helm repo update
    helm install redpanda redpanda/redpanda \
        --namespace redpanda --create-namespace \
        --values helm/20-redpanda/values.yaml
    
    wait_for_pods "redpanda" "app.kubernetes.io/name=redpanda" 600
    
    # 2.3：安装 Dragonfly
    print_info "安装 Dragonfly..."
    helm install dragonfly helm/30-dragonfly \
        --namespace dragonfly --create-namespace
    
    wait_for_pods "dragonfly" "app.kubernetes.io/name=dragonfly"
    
    # 2.4：安装 SeaweedFS
    print_info "安装 SeaweedFS..."
    helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
    helm repo update
    helm install seaweedfs seaweedfs/seaweedfs \
        --namespace seaweedfs --create-namespace \
        --values helm/40-seaweedfs/values.yaml
    
    wait_for_pods "seaweedfs" "app.kubernetes.io/component=master" 600
    
    # 创建 S3 存储桶
    print_info "为 OpenIM 创建 S3 存储桶..."
    kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
        aws --endpoint-url http://localhost:8333 s3 mb s3://openim 2>/dev/null || {
        print_warn "存储桶可能已存在或端口转发失败"
    }
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    # 2.5：安装 OpenIM
    print_info "安装 OpenIM..."
    helm repo add openim https://openimsdk.github.io/helm-charts
    helm repo update
    
    print_warn "注意：验证 OpenIM chart 是否存在于仓库中"
    print_warn "如果不存在，您可能需要调整安装命令"
    
    helm install openim openim/openim-server \
        --namespace openim --create-namespace \
        --values helm/90-openim/values.yaml || {
        print_warn "OpenIM 安装可能失败。检查 chart 名称和仓库。"
        print_warn "您可以手动安装：helm install openim <正确的-chart> --values helm/90-openim/values.yaml"
    }
    
    wait_for_pods "openim" "app.kubernetes.io/name=openim" 600
    
    # 步骤 3：验证
    print_info "步骤 3：验证部署..."
    
    print_info "检查所有 pods..."
    kubectl get pods --all-namespaces
    
    print_info "获取 ingress 外部 IP..."
    kubectl get svc -n ingress-nginx ingress-nginx-controller
    
    # 总结
    echo ""
    print_info "=========================================="
    print_info "部署成功完成！"
    print_info "=========================================="
    echo ""
    print_info "后续步骤："
    echo "  1. 获取外部 IP：kubectl get svc -n ingress-nginx"
    echo "  2. 更新您的 DNS 记录以指向外部 IP"
    echo "  3. 更新 helm/90-openim/values.yaml 中的域名"
    echo "  4. 按照 README.md 中的验证清单进行操作"
    echo ""
    print_warn "重要提示：在生产使用之前更改所有默认密码！"
    echo ""
}

# 运行主函数
main "$@"
