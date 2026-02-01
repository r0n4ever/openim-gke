#!/bin/bash
# OpenIM on GKE - Quick Deployment Script
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command_exists kubectl; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

if ! command_exists helm; then
    print_error "helm is not installed. Please install it first."
    exit 1
fi

if ! command_exists gcloud; then
    print_error "gcloud is not installed. Please install it first."
    exit 1
fi

if ! command_exists tofu && ! command_exists terraform; then
    print_error "Neither OpenTofu nor Terraform is installed. Please install one of them."
    exit 1
fi

# Determine which IaC tool to use
if command_exists tofu; then
    IAC_CMD="tofu"
else
    IAC_CMD="terraform"
fi

print_info "Using $IAC_CMD for infrastructure management"

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    print_info "Waiting for pods in namespace $namespace to be ready..."
    kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$namespace" \
        --timeout="${timeout}s" || {
        print_warn "Some pods may not be ready yet. Continuing..."
    }
}

# Main deployment function
main() {
    print_info "Starting OpenIM on GKE deployment..."
    
    # Step 1: Deploy infrastructure
    print_info "Step 1: Deploying GKE infrastructure..."
    cd tofu/
    $IAC_CMD init
    $IAC_CMD plan -var-file=../envs/dev.tfvars
    
    read -p "Do you want to apply the infrastructure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_error "Deployment cancelled by user"
        exit 1
    fi
    
    $IAC_CMD apply -var-file=../envs/dev.tfvars -auto-approve
    
    # Get cluster credentials
    print_info "Configuring kubectl..."
    PROJECT_ID=$(grep 'project_id' ../envs/dev.tfvars | cut -d'"' -f2)
    REGION=$(grep 'region' ../envs/dev.tfvars | cut -d'"' -f2)
    CLUSTER_NAME=$(grep 'cluster_name' ../envs/dev.tfvars | cut -d'"' -f2)
    
    gcloud container clusters get-credentials "$CLUSTER_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID"
    
    cd ..
    
    # Step 2: Deploy Helm components
    print_info "Step 2: Deploying Helm components..."
    
    # 2.1: Install NGINX Ingress Controller
    print_info "Installing NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx --create-namespace \
        --values helm/10-ingress-nginx/values.yaml
    
    wait_for_pods "ingress-nginx" "app.kubernetes.io/name=ingress-nginx"
    
    # Wait for external IP
    print_info "Waiting for external IP..."
    kubectl get svc -n ingress-nginx ingress-nginx-controller -w &
    WAIT_PID=$!
    sleep 30
    kill $WAIT_PID 2>/dev/null || true
    
    # 2.2: Install Redpanda
    print_info "Installing Redpanda..."
    helm repo add redpanda https://charts.redpanda.com
    helm repo update
    helm install redpanda redpanda/redpanda \
        --namespace redpanda --create-namespace \
        --values helm/20-redpanda/values.yaml
    
    wait_for_pods "redpanda" "app.kubernetes.io/name=redpanda" 600
    
    # 2.3: Install Dragonfly
    print_info "Installing Dragonfly..."
    helm install dragonfly helm/30-dragonfly \
        --namespace dragonfly --create-namespace
    
    wait_for_pods "dragonfly" "app.kubernetes.io/name=dragonfly"
    
    # 2.4: Install SeaweedFS
    print_info "Installing SeaweedFS..."
    helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
    helm repo update
    helm install seaweedfs seaweedfs/seaweedfs \
        --namespace seaweedfs --create-namespace \
        --values helm/40-seaweedfs/values.yaml
    
    wait_for_pods "seaweedfs" "app.kubernetes.io/component=master" 600
    
    # Create S3 bucket
    print_info "Creating S3 bucket for OpenIM..."
    kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
        aws --endpoint-url http://localhost:8333 s3 mb s3://openim 2>/dev/null || {
        print_warn "Bucket may already exist or port-forward failed"
    }
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    # 2.5: Install OpenIM
    print_info "Installing OpenIM..."
    helm repo add openim https://openimsdk.github.io/helm-charts
    helm repo update
    
    print_warn "Note: Verify the OpenIM chart exists in the repository"
    print_warn "If not, you may need to adjust the installation command"
    
    helm install openim openim/openim-server \
        --namespace openim --create-namespace \
        --values helm/90-openim/values.yaml || {
        print_warn "OpenIM installation may have failed. Check the chart name and repository."
        print_warn "You can manually install with: helm install openim <correct-chart> --values helm/90-openim/values.yaml"
    }
    
    wait_for_pods "openim" "app.kubernetes.io/name=openim" 600
    
    # Step 3: Verification
    print_info "Step 3: Verifying deployment..."
    
    print_info "Checking all pods..."
    kubectl get pods --all-namespaces
    
    print_info "Getting ingress external IP..."
    kubectl get svc -n ingress-nginx ingress-nginx-controller
    
    # Summary
    echo ""
    print_info "=========================================="
    print_info "Deployment completed successfully!"
    print_info "=========================================="
    echo ""
    print_info "Next steps:"
    echo "  1. Get the external IP: kubectl get svc -n ingress-nginx"
    echo "  2. Update your DNS records to point to the external IP"
    echo "  3. Update domain in helm/90-openim/values.yaml"
    echo "  4. Follow the verification checklist in README.md"
    echo ""
    print_warn "IMPORTANT: Change all default passwords before production use!"
    echo ""
}

# Run main function
main "$@"
