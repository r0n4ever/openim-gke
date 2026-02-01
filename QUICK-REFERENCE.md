# Quick Reference Guide / 快速参考指南

This document provides quick commands for common operations.

## 📋 Table of Contents

- [Initial Deployment](#initial-deployment)
- [Status Checks](#status-checks)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Initial Deployment

### Option 1: Automated Script (Recommended)

```bash
# Run the automated deployment script
./deploy.sh
```

### Option 2: Manual Step-by-Step

```bash
# 1. Deploy infrastructure
cd tofu/
tofu init
tofu apply -var-file=../envs/dev.tfvars

# 2. Configure kubectl
gcloud container clusters get-credentials <cluster-name> --region <region>

# 3. Install components (see README.md for full commands)
```

## Status Checks

### Check All Components

```bash
# Check all pods across all namespaces
kubectl get pods --all-namespaces

# Check specific namespace
kubectl get pods -n <namespace>

# Watch pods in real-time
kubectl get pods -n <namespace> -w
```

### Check Services

```bash
# Get all services
kubectl get svc --all-namespaces

# Get ingress external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### Check Storage

```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc --all-namespaces
```

### Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n <namespace>
```

## Common Operations

### View Logs

```bash
# View logs for a pod
kubectl logs -n <namespace> <pod-name>

# Follow logs in real-time
kubectl logs -n <namespace> <pod-name> -f

# View logs for all pods with a label
kubectl logs -n <namespace> -l app=<app-name> --tail=50
```

### Execute Commands in Pods

```bash
# Open a shell in a pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/bash

# Run a single command
kubectl exec -n <namespace> <pod-name> -- <command>
```

### Port Forwarding

```bash
# Forward local port to pod
kubectl port-forward -n <namespace> <pod-name> <local-port>:<remote-port>

# Forward to a service
kubectl port-forward -n <namespace> svc/<service-name> <local-port>:<remote-port>
```

### Scale Deployments

```bash
# Scale a deployment
kubectl scale deployment -n <namespace> <deployment-name> --replicas=<count>

# Example: Scale OpenIM API
kubectl scale deployment -n openim openim-api --replicas=3
```

### Restart Components

```bash
# Restart a deployment (rolling restart)
kubectl rollout restart deployment -n <namespace> <deployment-name>

# Restart a statefulset
kubectl rollout restart statefulset -n <namespace> <statefulset-name>

# Check rollout status
kubectl rollout status deployment -n <namespace> <deployment-name>
```

### Update Helm Releases

```bash
# Update a Helm release
helm upgrade <release-name> <chart> \
  --namespace <namespace> \
  --values <values-file>

# Example: Update OpenIM
helm upgrade openim openim/openim-server \
  --namespace openim \
  --values helm/90-openim/values.yaml

# Rollback a release
helm rollback <release-name> -n <namespace>
```

## Component-Specific Commands

### Redpanda (Kafka)

```bash
# Check cluster status
kubectl exec -it redpanda-0 -n redpanda -- rpk cluster info

# List topics
kubectl exec -it redpanda-0 -n redpanda -- rpk topic list

# Create a topic
kubectl exec -it redpanda-0 -n redpanda -- rpk topic create <topic-name>

# Describe a topic
kubectl exec -it redpanda-0 -n redpanda -- rpk topic describe <topic-name>

# Delete a topic
kubectl exec -it redpanda-0 -n redpanda -- rpk topic delete <topic-name>
```

### Dragonfly (Redis)

```bash
# Test connection
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping

# Check memory info
kubectl exec -n dragonfly dragonfly-0 -- redis-cli INFO memory

# Get all keys (use with caution in production)
kubectl exec -n dragonfly dragonfly-0 -- redis-cli KEYS '*'

# Get specific key
kubectl exec -n dragonfly dragonfly-0 -- redis-cli GET <key>

# Monitor commands in real-time
kubectl exec -it -n dragonfly dragonfly-0 -- redis-cli MONITOR
```

### SeaweedFS (S3)

```bash
# Port-forward S3 API
kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333

# List buckets
AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
  aws --endpoint-url http://localhost:8333 s3 ls

# Create bucket
AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
  aws --endpoint-url http://localhost:8333 s3 mb s3://<bucket-name>

# Upload file
AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
  aws --endpoint-url http://localhost:8333 s3 cp <file> s3://<bucket>/<path>

# Download file
AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
  aws --endpoint-url http://localhost:8333 s3 cp s3://<bucket>/<path> <local-file>

# List objects in bucket
AWS_ACCESS_KEY_ID=admin AWS_SECRET_ACCESS_KEY=admin123 \
  aws --endpoint-url http://localhost:8333 s3 ls s3://<bucket>/
```

### MySQL

```bash
# Connect to MySQL
kubectl run mysql-client --rm -it --restart=Never --image=mysql:8.0 -n openim -- \
  mysql -h openim-mysql -u openIM -popenIM123

# Execute query
kubectl run mysql-client --rm -it --restart=Never --image=mysql:8.0 -n openim -- \
  mysql -h openim-mysql -u openIM -popenIM123 -e "SHOW DATABASES;"

# Backup database
kubectl exec -n openim openim-mysql-0 -- \
  mysqldump -u root -popenIM123 openIM_v3 > backup.sql

# Restore database
cat backup.sql | kubectl exec -i -n openim openim-mysql-0 -- \
  mysql -u root -popenIM123 openIM_v3
```

### OpenIM

```bash
# Port-forward API server
kubectl port-forward -n openim svc/openim-api 10002:10002

# Test health endpoint
curl http://localhost:10002/health

# Port-forward message gateway (WebSocket)
kubectl port-forward -n openim svc/openim-msggateway 10001:10001

# View API logs
kubectl logs -n openim -l app=openim-api --tail=100 -f

# View message gateway logs
kubectl logs -n openim -l app=openim-msggateway --tail=100 -f
```

## Troubleshooting

### Check Events

```bash
# Get recent events in namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n <namespace> --watch
```

### Describe Resources

```bash
# Describe a pod (shows events and status)
kubectl describe pod -n <namespace> <pod-name>

# Describe a service
kubectl describe svc -n <namespace> <service-name>

# Describe a persistent volume claim
kubectl describe pvc -n <namespace> <pvc-name>
```

### Network Troubleshooting

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup <service-name>.<namespace>.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv <service-name>.<namespace>.svc.cluster.local <port>

# Advanced network debugging
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
```

### Check Resource Quotas and Limits

```bash
# Check resource quotas
kubectl get resourcequota -n <namespace>

# Check limit ranges
kubectl get limitrange -n <namespace>

# Check pod resource requests and limits
kubectl describe pod -n <namespace> <pod-name> | grep -A 10 "Requests\|Limits"
```

## Cleanup

### Delete Helm Releases

```bash
# Delete a Helm release
helm uninstall <release-name> -n <namespace>

# Delete all Helm releases in order (reverse of installation)
helm uninstall openim -n openim
helm uninstall seaweedfs -n seaweedfs
helm uninstall dragonfly -n dragonfly
helm uninstall redpanda -n redpanda
helm uninstall ingress-nginx -n ingress-nginx
```

### Delete Namespaces

```bash
# Delete a namespace and all resources in it
kubectl delete namespace <namespace>

# Delete all OpenIM-related namespaces
kubectl delete namespace openim seaweedfs dragonfly redpanda ingress-nginx
```

### Destroy Infrastructure

```bash
# Destroy GKE cluster
cd tofu/
tofu destroy -var-file=../envs/dev.tfvars
```

### Complete Cleanup

```bash
# 1. Delete all Helm releases
helm uninstall openim -n openim
helm uninstall seaweedfs -n seaweedfs
helm uninstall dragonfly -n dragonfly
helm uninstall redpanda -n redpanda
helm uninstall ingress-nginx -n ingress-nginx

# 2. Delete all namespaces
kubectl delete namespace openim seaweedfs dragonfly redpanda ingress-nginx

# 3. Destroy infrastructure
cd tofu/
tofu destroy -var-file=../envs/dev.tfvars -auto-approve

# 4. Clean up local state
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Monitoring and Observability

### Get Service Metrics

```bash
# Check if metrics are available
kubectl get --raw /metrics

# Get node metrics
kubectl top nodes

# Get pod metrics
kubectl top pods --all-namespaces
```

### Access Component UIs (if available)

```bash
# Redpanda Console (if deployed)
kubectl port-forward -n redpanda svc/redpanda-console 8080:8080

# SeaweedFS Master UI
kubectl port-forward -n seaweedfs svc/seaweedfs-master 9333:9333
# Access: http://localhost:9333

# SeaweedFS Filer UI
kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8888:8888
# Access: http://localhost:8888
```

## Configuration Updates

### Update Infrastructure Variables

```bash
# Edit variables
vim envs/dev.tfvars

# Apply changes
cd tofu/
tofu plan -var-file=../envs/dev.tfvars
tofu apply -var-file=../envs/dev.tfvars
```

### Update Component Configuration

```bash
# Edit Helm values
vim helm/<component>/values.yaml

# Apply changes
helm upgrade <release-name> <chart> \
  --namespace <namespace> \
  --values helm/<component>/values.yaml
```

## Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'

# OpenIM specific
alias kgo='kubectl get pods -n openim'
alias klo='kubectl logs -n openim'
alias kgr='kubectl get pods -n redpanda'
alias kgs='kubectl get pods -n seaweedfs'
alias kgd='kubectl get pods -n dragonfly'

# Helm
alias h='helm'
alias hl='helm list'
alias hg='helm get'
alias hu='helm upgrade'
```

## Quick Verification Script

Save this as `verify.sh`:

```bash
#!/bin/bash
echo "=== Checking all namespaces ==="
kubectl get pods --all-namespaces

echo -e "\n=== Checking services ==="
kubectl get svc --all-namespaces

echo -e "\n=== Checking ingress ==="
kubectl get ingress --all-namespaces

echo -e "\n=== Checking PVCs ==="
kubectl get pvc --all-namespaces

echo -e "\n=== Node resources ==="
kubectl top nodes

echo -e "\n=== External IP ==="
kubectl get svc -n ingress-nginx ingress-nginx-controller

echo -e "\n=== Recent events ==="
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

Make it executable:
```bash
chmod +x verify.sh
./verify.sh
```

---

For more detailed information, refer to:
- Main README: `README.MD`
- Component-specific READMEs: `helm/*/README.md`
- Official documentation for each component
