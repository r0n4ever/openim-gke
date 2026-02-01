# Production Readiness Checklist

This checklist helps you ensure your OpenIM deployment is production-ready.

## 🔐 Security

### Credentials and Secrets

- [ ] **Change MySQL root password** from default (`openIM123`)
  - Location: `helm/90-openim/values.yaml` → `mysql.auth.rootPassword`
  - Generate strong password: `openssl rand -base64 32`

- [ ] **Change MySQL user password** from default (`openIM123`)
  - Location: `helm/90-openim/values.yaml` → `mysql.auth.password`

- [ ] **Change SeaweedFS S3 credentials** from default (`admin`/`admin123`)
  - Location: `helm/40-seaweedfs/values.yaml` → `filer.s3.config`
  - Update in: `helm/90-openim/values.yaml` → `object.minio.accessKeyID` and `secretAccessKey`

- [ ] **Enable authentication for Redpanda**
  - Add SASL/SCRAM configuration
  - Update connection strings in OpenIM values

- [ ] **Enable authentication for Dragonfly**
  - Add password in `helm/30-dragonfly/values.yaml`
  - Update OpenIM configuration with password

- [ ] **Store secrets in Kubernetes Secrets** (not in values.yaml)
  ```bash
  kubectl create secret generic openim-secrets \
    -n openim \
    --from-literal=mysql-password=<password> \
    --from-literal=s3-access-key=<key> \
    --from-literal=s3-secret-key=<secret>
  ```

- [ ] **Consider using External Secrets Operator** or Google Secret Manager

### TLS/SSL

- [ ] **Install cert-manager**
  ```bash
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set installCRDs=true
  ```

- [ ] **Configure Let's Encrypt issuer**
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: your-email@example.com
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
      - http01:
          ingress:
            class: nginx
  ```

- [ ] **Enable TLS for Ingress**
  - Update `helm/90-openim/values.yaml` with TLS configuration
  - Add cert-manager annotations

- [ ] **Enable TLS for internal components**
  - Redpanda inter-broker TLS
  - MySQL TLS connections
  - SeaweedFS S3 TLS

### Network Security

- [ ] **Implement Network Policies** to restrict pod-to-pod communication
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: openim-network-policy
    namespace: openim
  spec:
    podSelector:
      matchLabels:
        app.kubernetes.io/name: openim
    policyTypes:
    - Ingress
    - Egress
    ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
    egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: redpanda
      ports:
      - protocol: TCP
        port: 9092
  ```

- [ ] **Configure GKE Private Cluster** (if applicable)
- [ ] **Enable GKE Workload Identity** for pod authentication
- [ ] **Configure firewall rules** for GKE nodes
- [ ] **Review and minimize ingress rules**

### Access Control

- [ ] **Implement RBAC** for Kubernetes access
- [ ] **Use GCP IAM** for GKE cluster access
- [ ] **Set up audit logging** for Kubernetes API
- [ ] **Configure Pod Security Standards**
- [ ] **Review service account permissions**

## 🏗️ High Availability

### Database

- [ ] **Enable MySQL replication**
  ```yaml
  mysql:
    architecture: replication
    secondary:
      replicaCount: 1
  ```

- [ ] **Configure automated backups**
- [ ] **Test database failover**
- [ ] **Set up cross-region replication** (if needed)

### Application Components

- [ ] **Increase replica counts** for all OpenIM services
  - API: At least 3 replicas
  - Message Gateway: At least 3 replicas
  - All RPC services: At least 2 replicas

- [ ] **Configure Pod Disruption Budgets**
  ```yaml
  apiVersion: policy/v1
  kind: PodDisruptionBudget
  metadata:
    name: openim-api-pdb
    namespace: openim
  spec:
    minAvailable: 2
    selector:
      matchLabels:
        app: openim-api
  ```

- [ ] **Set up Horizontal Pod Autoscaling**
  ```bash
  kubectl autoscale deployment openim-api \
    -n openim \
    --cpu-percent=70 \
    --min=3 \
    --max=10
  ```

### Infrastructure

- [ ] **Use multi-zone GKE cluster**
  - Verify in `tofu/main.tf` that cluster spans multiple zones

- [ ] **Configure node auto-repair and auto-upgrade**
  - Already enabled in `tofu/main.tf`

- [ ] **Set appropriate resource requests and limits**
  - Review all `values.yaml` files

- [ ] **Configure pod anti-affinity** for critical services

## 📊 Monitoring and Observability

### Metrics

- [ ] **Install Prometheus and Grafana**
  ```bash
  helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace
  ```

- [ ] **Configure ServiceMonitors** for all components
- [ ] **Import Grafana dashboards** for:
  - Kubernetes cluster metrics
  - Redpanda metrics
  - MySQL metrics
  - OpenIM application metrics

- [ ] **Set up custom dashboards** for:
  - Message delivery latency
  - API response times
  - WebSocket connection count
  - Storage usage

### Logging

- [ ] **Install logging stack** (Elastic/Loki)
  ```bash
  helm install loki grafana/loki-stack \
    --namespace logging --create-namespace \
    --set promtail.enabled=true \
    --set grafana.enabled=true
  ```

- [ ] **Configure log retention policies**
- [ ] **Set up log aggregation**
- [ ] **Enable structured logging** in applications

### Alerting

- [ ] **Configure Alertmanager**
- [ ] **Set up alerts for**:
  - Pod crashes/restarts
  - High CPU/memory usage
  - Database connection failures
  - Disk space usage > 80%
  - API error rate > 5%
  - Message delivery failures
  - Certificate expiration
  - Backup failures

- [ ] **Configure notification channels** (Slack/PagerDuty/Email)
- [ ] **Test alerting rules**

### Tracing

- [ ] **Install distributed tracing** (Jaeger/Zipkin)
- [ ] **Configure OpenIM for tracing**
- [ ] **Set up service mesh** (optional, for advanced tracing)

## 💾 Backup and Disaster Recovery

### Database Backups

- [ ] **Configure automated MySQL backups**
  ```bash
  # Example cronjob for backups
  kubectl create cronjob mysql-backup \
    -n openim \
    --image=mysql:8.0 \
    --schedule="0 2 * * *" \
    -- /bin/sh -c "mysqldump -h openim-mysql -u root -p\$MYSQL_ROOT_PASSWORD openIM_v3 | gzip > /backup/backup-\$(date +%Y%m%d).sql.gz"
  ```

- [ ] **Store backups in GCS**
  ```bash
  gsutil cp backup.sql.gz gs://your-backup-bucket/mysql/
  ```

- [ ] **Test backup restoration**
- [ ] **Set backup retention policy** (e.g., 30 days)

### Object Storage Backups

- [ ] **Configure SeaweedFS backup to GCS**
- [ ] **Set up volume snapshots** for SeaweedFS
- [ ] **Test restore procedures**

### Configuration Backups

- [ ] **Store Helm values in version control** (Git)
- [ ] **Export and backup Kubernetes secrets** (encrypted)
  ```bash
  kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml
  # Encrypt this file!
  ```

- [ ] **Document all manual configuration changes**

### Disaster Recovery Plan

- [ ] **Document DR procedures**
- [ ] **Define RTO and RPO targets**
  - RTO (Recovery Time Objective): How long to restore?
  - RPO (Recovery Point Objective): How much data loss acceptable?

- [ ] **Test DR procedures regularly**
- [ ] **Set up multi-region deployment** (if needed)
- [ ] **Configure DNS failover**

## 🚀 Performance Optimization

### Resource Tuning

- [ ] **Run load tests** to determine appropriate resource limits
- [ ] **Monitor and adjust based on actual usage**
- [ ] **Enable GKE cluster autoscaling**
- [ ] **Use node pools with appropriate machine types**

### Database Optimization

- [ ] **Tune MySQL configuration**
  - innodb_buffer_pool_size
  - max_connections
  - query_cache_size

- [ ] **Add indexes for slow queries**
- [ ] **Configure connection pooling**
- [ ] **Monitor slow query log**

### Caching Optimization

- [ ] **Tune Dragonfly memory limits**
- [ ] **Configure appropriate eviction policies**
- [ ] **Monitor cache hit rates**
- [ ] **Review and optimize cache keys**

### Storage Optimization

- [ ] **Use SSD persistent disks** for databases
- [ ] **Configure appropriate storage classes**
- [ ] **Monitor disk I/O performance**
- [ ] **Implement lifecycle policies** for object storage

## 📈 Scalability

### Horizontal Scaling

- [ ] **Configure HPA for all services**
- [ ] **Set appropriate scaling metrics**
- [ ] **Test scaling under load**
- [ ] **Monitor scaling events**

### Vertical Scaling

- [ ] **Use Vertical Pod Autoscaler** (VPA) for recommendations
- [ ] **Right-size based on actual usage**

### Data Scaling

- [ ] **Plan for data growth**
- [ ] **Configure data retention policies**
- [ ] **Implement data archival strategy**
- [ ] **Test with production-size datasets**

## 🔍 Testing

### Functional Testing

- [ ] **Test user registration and login**
- [ ] **Test message sending and receiving**
- [ ] **Test file upload and download**
- [ ] **Test WebSocket connections**
- [ ] **Test all API endpoints**

### Performance Testing

- [ ] **Run load tests**
  - Expected concurrent users
  - Message throughput
  - File upload/download rates

- [ ] **Test under sustained load**
- [ ] **Identify bottlenecks**
- [ ] **Test with realistic data volumes**

### Chaos Engineering

- [ ] **Test pod failures**
  ```bash
  kubectl delete pod <pod-name> -n <namespace>
  ```

- [ ] **Test node failures**
- [ ] **Test network partitions**
- [ ] **Test resource exhaustion**
- [ ] **Verify automatic recovery**

### Security Testing

- [ ] **Run vulnerability scans** on container images
- [ ] **Perform penetration testing**
- [ ] **Test authentication and authorization**
- [ ] **Review security audit logs**

## 📋 Documentation

### Operational Documentation

- [ ] **Document deployment procedures**
- [ ] **Create runbooks for common operations**
  - Scaling
  - Backup/Restore
  - Incident response
  - Certificate renewal

- [ ] **Document architecture and dependencies**
- [ ] **Create troubleshooting guide**
- [ ] **Document monitoring and alerting**

### Developer Documentation

- [ ] **API documentation**
- [ ] **Integration guides**
- [ ] **Development environment setup**
- [ ] **Code contribution guidelines**

## 🎯 Compliance and Legal

### Data Protection

- [ ] **Implement data encryption at rest**
- [ ] **Implement data encryption in transit**
- [ ] **Configure data retention policies**
- [ ] **Implement right to deletion** (GDPR)
- [ ] **Set up data backup and recovery**

### Audit and Compliance

- [ ] **Enable audit logging**
- [ ] **Configure log retention** for compliance
- [ ] **Implement access controls**
- [ ] **Document security controls**
- [ ] **Regular security audits**

## 🔄 Continuous Improvement

### Process

- [ ] **Set up CI/CD pipelines**
- [ ] **Automate testing**
- [ ] **Implement GitOps** (ArgoCD/FluxCD)
- [ ] **Regular security updates**
- [ ] **Monitor for component updates**

### Review Cycles

- [ ] **Weekly operational reviews**
- [ ] **Monthly performance reviews**
- [ ] **Quarterly capacity planning**
- [ ] **Annual disaster recovery testing**

## ✅ Pre-Launch Verification

Before going live:

- [ ] **Complete security checklist**
- [ ] **Run full test suite**
- [ ] **Load test with expected traffic**
- [ ] **Verify all monitoring and alerts work**
- [ ] **Test backup and restore**
- [ ] **Review and sign off on DR plan**
- [ ] **Train operations team**
- [ ] **Prepare incident response procedures**
- [ ] **Schedule maintenance windows**
- [ ] **Notify stakeholders of launch**

## 📞 Support and Escalation

- [ ] **Define support tiers and SLAs**
- [ ] **Set up on-call rotation**
- [ ] **Create escalation procedures**
- [ ] **Document contact information**
- [ ] **Set up incident management system**

---

## Summary

**Critical Items (Must Complete):**
1. Change all default passwords
2. Enable TLS/SSL
3. Configure backups
4. Set up monitoring and alerting
5. Test disaster recovery
6. Implement RBAC and network policies
7. Configure high availability
8. Load test with production traffic

**Important Items (Should Complete):**
1. Implement comprehensive logging
2. Set up distributed tracing
3. Configure auto-scaling
4. Optimize resource usage
5. Complete operational documentation
6. Set up CI/CD pipelines

**Nice to Have (Can Complete Post-Launch):**
1. Advanced monitoring dashboards
2. Service mesh implementation
3. Multi-region deployment
4. Advanced chaos engineering
5. Performance optimization

Use this checklist to track your progress toward a production-ready deployment!
