# OpenIM Server - Instant Messaging Application

This directory contains the Helm values for the OpenIM server application, configured to use all the custom replacement components:

- **Kafka** → **Redpanda** (message queue)
- **Redis** → **Dragonfly** (cache and session store)
- **MinIO** → **SeaweedFS** (object storage for files and media)
- **MySQL** (official chart, database)

## Prerequisites

Before installing OpenIM, ensure all dependencies are running:

1. ✅ Ingress NGINX (10-ingress-nginx)
2. ✅ Redpanda (20-redpanda)
3. ✅ Dragonfly (30-dragonfly)
4. ✅ SeaweedFS (40-seaweedfs)

```bash
# Verify all dependencies are running
kubectl get pods -n ingress-nginx
kubectl get pods -n redpanda
kubectl get pods -n dragonfly
kubectl get pods -n seaweedfs
```

## Installation

```bash
# Add the OpenIM Helm repository
helm repo add openim https://openimsdk.github.io/helm-charts
helm repo update

# Install OpenIM
helm install openim openim/openim-server \
  --namespace openim --create-namespace \
  --values helm/90-openim/values.yaml
```

**Note**: The actual chart name and repository might differ. Verify with:
```bash
helm search repo openim
```

## Pre-Installation Setup

### 1. Create Storage Bucket

SeaweedFS needs a bucket for OpenIM:

```bash
# Port-forward SeaweedFS S3 API
kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333 &

# Create the openim bucket
aws --endpoint-url http://localhost:8333 \
    --region us-east-1 \
    s3 mb s3://openim

# Verify bucket creation
aws --endpoint-url http://localhost:8333 \
    --region us-east-1 \
    s3 ls
```

### 2. Configure Domain (TODO)

Update `helm/90-openim/values.yaml`:
```yaml
global:
  domain: "your-domain.com"  # Replace with your actual domain

ingress:
  hosts:
    - host: your-domain.com  # Replace with your actual domain
```

Then update DNS records to point to the Ingress NGINX external IP:
```bash
# Get the external IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Add DNS A record:
# your-domain.com -> EXTERNAL-IP
```

## Verification

### Check All Pods

```bash
# Check OpenIM pods
kubectl get pods -n openim

# All pods should be in Running state
kubectl get all -n openim
```

### Verify Component Connectivity

```bash
# Test MySQL connection
kubectl run -it --rm mysql-test --image=mysql:8.0 --restart=Never -n openim -- \
  mysql -h openim-mysql -u openIM -popenIM123 -e "SHOW DATABASES;"

# Test Redpanda (Kafka) connection
kubectl run -it --rm kafka-test --image=redpandadata/redpanda --restart=Never -- \
  rpk topic list --brokers redpanda.redpanda.svc.cluster.local:9092

# Test Dragonfly (Redis) connection
kubectl run -it --rm redis-test --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping

# Test SeaweedFS S3 connection
kubectl run -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  s3 ls s3://openim
```

### Test OpenIM API

```bash
# Port-forward the API server
kubectl port-forward -n openim svc/openim-api 10002:10002

# Test health endpoint
curl http://localhost:10002/health

# Check version
curl http://localhost:10002/version
```

### Test WebSocket Connection

```bash
# Port-forward the message gateway
kubectl port-forward -n openim svc/openim-msggateway 10001:10001

# Test WebSocket connection with websocat (install if needed)
# sudo apt-get install websocat
echo '{"type":"ping"}' | websocat ws://localhost:10001/ws
```

## Configuration Overview

### Component Mapping

| OpenIM Component | Replacement | Connection String |
|-----------------|-------------|-------------------|
| Kafka | Redpanda | `redpanda.redpanda.svc.cluster.local:9092` |
| Redis | Dragonfly | `dragonfly.dragonfly.svc.cluster.local:6379` |
| MinIO | SeaweedFS | `http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333` |
| MySQL | MySQL (official) | `openim-mysql.openim.svc.cluster.local:3306` |

### No Code Changes Required

All replacements use standard APIs:
- **Redpanda**: 100% Kafka API compatible
- **Dragonfly**: 100% Redis protocol compatible
- **SeaweedFS**: S3 API compatible (MinIO compatible)

OpenIM application code requires **zero modifications** to work with these replacements.

## Monitoring

### View Logs

```bash
# API server logs
kubectl logs -n openim -l app=openim-api --tail=100 -f

# Message gateway logs
kubectl logs -n openim -l app=openim-msggateway --tail=100 -f

# Message transfer logs
kubectl logs -n openim -l app=openim-msgtransfer --tail=100 -f
```

### Resource Usage

```bash
# Check resource consumption
kubectl top pods -n openim

# Check node resource usage
kubectl top nodes
```

### Service Status

```bash
# Check all services
kubectl get svc -n openim

# Check ingress
kubectl get ingress -n openim
```

## Validation Checklist

Use this checklist to verify your deployment:

- [ ] **Infrastructure**
  - [ ] GKE cluster is running
  - [ ] All nodes are healthy
  - [ ] Storage classes are available

- [ ] **Dependencies**
  - [ ] Ingress NGINX is running with external IP
  - [ ] Redpanda cluster is healthy (3/3 pods)
  - [ ] Dragonfly is running (2/2 pods)
  - [ ] SeaweedFS is running (all components up)

- [ ] **Database**
  - [ ] MySQL is running and accepting connections
  - [ ] OpenIM database and tables are created
  - [ ] Database migrations completed successfully

- [ ] **OpenIM Services**
  - [ ] All OpenIM pods are in Running state
  - [ ] API server is accessible
  - [ ] Message gateway accepts WebSocket connections

- [ ] **Connectivity**
  - [ ] OpenIM can connect to Redpanda (check logs)
  - [ ] OpenIM can connect to Dragonfly (check logs)
  - [ ] OpenIM can connect to SeaweedFS (check logs)
  - [ ] OpenIM can connect to MySQL (check logs)

- [ ] **API Testing**
  - [ ] Health check endpoint returns 200
  - [ ] User registration works
  - [ ] User login works
  - [ ] Sending messages works
  - [ ] File upload works (tests SeaweedFS)

- [ ] **WebSocket Testing**
  - [ ] WebSocket connection establishes
  - [ ] Real-time message delivery works
  - [ ] Online status updates work

- [ ] **Storage Testing**
  - [ ] Images can be uploaded
  - [ ] Videos can be uploaded
  - [ ] Files can be downloaded
  - [ ] Object storage bucket has files

- [ ] **Observability**
  - [ ] Logs are accessible for all components
  - [ ] Metrics endpoints are exposed
  - [ ] No error messages in logs

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n openim <pod-name>

# Check events
kubectl get events -n openim --sort-by='.lastTimestamp'

# Check resource quotas
kubectl describe resourcequota -n openim
```

### Database Connection Issues

```bash
# Verify MySQL is accessible
kubectl exec -it -n openim <openim-pod> -- nc -zv openim-mysql 3306

# Check MySQL logs
kubectl logs -n openim -l app=mysql

# Verify credentials
kubectl get secret -n openim openim-mysql -o yaml
```

### Redpanda/Kafka Connection Issues

```bash
# Test from OpenIM pod
kubectl exec -it -n openim <openim-pod> -- \
  nc -zv redpanda.redpanda.svc.cluster.local 9092

# Check Redpanda logs
kubectl logs -n redpanda redpanda-0

# List topics
kubectl exec -it redpanda-0 -n redpanda -- rpk topic list
```

### Dragonfly/Redis Connection Issues

```bash
# Test from OpenIM pod
kubectl exec -it -n openim <openim-pod> -- \
  nc -zv dragonfly.dragonfly.svc.cluster.local 6379

# Check Dragonfly logs
kubectl logs -n dragonfly dragonfly-0

# Test Redis commands
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping
```

### SeaweedFS/S3 Connection Issues

```bash
# Test from OpenIM pod
kubectl exec -it -n openim <openim-pod> -- \
  nc -zv seaweedfs-filer.seaweedfs.svc.cluster.local 8333

# Check SeaweedFS filer logs
kubectl logs -n seaweedfs -l app.kubernetes.io/component=filer

# Verify bucket exists
kubectl run s3-test --rm -it --restart=Never --image=amazon/aws-cli -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  s3 ls s3://openim
```

### Ingress Issues

```bash
# Check ingress status
kubectl describe ingress -n openim

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Verify external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## Scaling

### Scale OpenIM Components

```bash
# Scale API servers
kubectl scale deployment -n openim openim-api --replicas=3

# Scale message gateway
kubectl scale deployment -n openim openim-msggateway --replicas=3

# Or use Helm upgrade
helm upgrade openim openim/openim-server \
  --namespace openim \
  --values helm/90-openim/values.yaml \
  --set api.replicaCount=3 \
  --set msggateway.replicaCount=3
```

### Horizontal Pod Autoscaling

```bash
# Enable HPA for API server
kubectl autoscale deployment -n openim openim-api \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

## Upgrade and Rollback

### Upgrade OpenIM

```bash
# Update Helm repository
helm repo update

# Upgrade to latest version
helm upgrade openim openim/openim-server \
  --namespace openim \
  --values helm/90-openim/values.yaml
```

### Rollback

```bash
# Check revision history
helm history -n openim openim

# Rollback to previous version
helm rollback openim -n openim

# Or rollback to specific revision
helm rollback openim 2 -n openim
```

## Production Considerations

### Security (TODO)

1. **Change Default Passwords**:
   ```yaml
   mysql:
     auth:
       rootPassword: "<strong-password>"
       password: "<strong-password>"
   
   object:
     minio:
       accessKeyID: "<your-access-key>"
       secretAccessKey: "<your-secret-key>"
   ```

2. **Enable Authentication** for Redpanda and Dragonfly

3. **Enable TLS/SSL**:
   - Install cert-manager
   - Configure Let's Encrypt issuer
   - Update ingress with TLS configuration

4. **Network Policies**: Restrict pod-to-pod communication

### High Availability

1. **Database Replication**:
   ```yaml
   mysql:
     architecture: replication
     secondary:
       replicaCount: 1
   ```

2. **Increase Replicas** for all components:
   - API: 3+ replicas
   - Message Gateway: 3+ replicas
   - All RPC services: 2+ replicas

3. **Pod Disruption Budgets**: Ensure minimum availability during updates

### Backup Strategy

1. **MySQL Backups**:
   - Use Velero for automated backups
   - Or use MySQL native backup tools
   - Schedule regular backups to GCS

2. **SeaweedFS Backups**:
   - Replicate to GCS
   - Use volume snapshots

3. **Configuration Backups**:
   - Store Helm values in version control
   - Export secrets securely

### Monitoring and Alerting

1. **Prometheus + Grafana**:
   ```bash
   # Install Prometheus stack
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring --create-namespace
   ```

2. **Set Up Alerts** for:
   - Pod crashes
   - High resource usage
   - API errors
   - Database connection issues
   - Storage capacity

3. **Logging**:
   - Use Elastic Stack or Loki
   - Centralize logs from all components

### Performance Tuning

1. **Resource Optimization**: Monitor and adjust resource requests/limits

2. **Database Optimization**:
   - Tune MySQL configuration
   - Add indexes for slow queries
   - Consider read replicas

3. **Cache Optimization**:
   - Tune Dragonfly memory limits
   - Adjust eviction policies

4. **Storage Optimization**:
   - Use SSD storage classes for better performance
   - Configure appropriate replication factors

## Migration from Standard Components

If migrating from standard Kafka/Redis/MinIO:

1. **Data Migration**:
   - Use official migration tools
   - Test thoroughly in staging
   - Plan for minimal downtime

2. **Gradual Migration**:
   - Run both systems in parallel
   - Gradually shift traffic
   - Monitor for issues

3. **Rollback Plan**:
   - Keep old components available
   - Be prepared to switch back
   - Document rollback procedures

## PostgreSQL Support Note

OpenIM officially supports **MySQL** (used in this configuration). While PostgreSQL support is theoretically possible:

- Requires changing database driver in OpenIM configuration
- Schema compatibility needs testing
- Not officially supported or recommended
- May have unexpected issues

**For PostgreSQL support**, you would need to:
1. Research OpenIM PostgreSQL compatibility
2. Test schema migrations
3. Verify all features work correctly
4. This is outside the scope of this standard deployment

## Comparison: Standard vs. Replacement Components

| Feature | Standard | Replacement | Notes |
|---------|----------|-------------|-------|
| Message Queue | Kafka | Redpanda | Simpler, faster, Kafka-compatible |
| Cache | Redis | Dragonfly | 25x faster, Redis-compatible |
| Object Storage | MinIO | SeaweedFS | Simpler, efficient for small files |
| Database | MySQL | MySQL | Same (using official chart) |
| **Resource Usage** | High | Lower | ~30% reduction in CPU/memory |
| **Operational Complexity** | High | Lower | Fewer moving parts |
| **API Compatibility** | N/A | 100% | No code changes needed |
| **Ecosystem** | Large | Smaller | Fewer tools and integrations |
| **Maturity** | Very mature | Newer | Less battle-tested |

## TODO Items Summary

Before production deployment:

- [ ] Change all default passwords (MySQL, S3)
- [ ] Configure actual domain name
- [ ] Enable TLS/SSL with cert-manager
- [ ] Enable authentication for Redpanda and Dragonfly
- [ ] Set up monitoring and alerting
- [ ] Configure backup strategies
- [ ] Review and adjust resource limits
- [ ] Test failover scenarios
- [ ] Set up CI/CD pipelines
- [ ] Document runbooks for operations
- [ ] Verify OpenIM Helm chart field compatibility
- [ ] Load test the system
- [ ] Security audit
- [ ] Disaster recovery plan

## Support and Documentation

- **OpenIM**: https://github.com/openimsdk/open-im-server
- **Redpanda**: https://docs.redpanda.com/
- **Dragonfly**: https://www.dragonflydb.io/docs
- **SeaweedFS**: https://github.com/seaweedfs/seaweedfs/wiki

## Next Steps

After OpenIM is successfully deployed and verified:

1. Configure admin users
2. Test client applications
3. Set up monitoring dashboards
4. Implement backup procedures
5. Document operational procedures
6. Plan for production launch
