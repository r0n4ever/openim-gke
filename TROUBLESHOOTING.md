# Troubleshooting Guide

Common issues and their solutions for OpenIM on GKE deployment.

## 📑 Table of Contents

- [Infrastructure Issues](#infrastructure-issues)
- [Component-Specific Issues](#component-specific-issues)
- [Connectivity Issues](#connectivity-issues)
- [Performance Issues](#performance-issues)
- [Storage Issues](#storage-issues)
- [Security Issues](#security-issues)

## Infrastructure Issues

### Issue: GKE Cluster Creation Fails

**Symptoms:**
```
Error creating cluster: googleapi: Error 403: Insufficient regional quota
```

**Diagnosis:**
```bash
# Check current quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Check which APIs are enabled
gcloud services list --enabled --project=YOUR_PROJECT_ID
```

**Solution:**
1. Enable required APIs:
   ```bash
   gcloud services enable container.googleapis.com
   gcloud services enable compute.googleapis.com
   ```

2. Request quota increase:
   - Go to GCP Console → IAM & Admin → Quotas
   - Filter by region and resource type
   - Request increase for:
     - In-use IP addresses
     - CPUs
     - Persistent Disk SSD (GB)

3. Use a different region with available quota:
   ```bash
   # Update envs/dev.tfvars
   region = "us-east1"  # or another region
   ```

### Issue: Terraform/OpenTofu State Locked

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Diagnosis:**
```bash
# Check if process is actually running
ps aux | grep tofu
```

**Solution:**
1. If no process is running, force unlock:
   ```bash
   cd tofu/
   tofu force-unlock <LOCK_ID>
   ```

2. If using remote backend (GCS), check for stale locks:
   ```bash
   gsutil ls gs://your-terraform-state-bucket/
   ```

### Issue: kubectl Cannot Connect to Cluster

**Symptoms:**
```
Unable to connect to the server: dial tcp: lookup xxx on xxx: no such host
```

**Diagnosis:**
```bash
# Check kubeconfig
kubectl config view

# Check cluster status
gcloud container clusters describe <cluster-name> --region <region>
```

**Solution:**
1. Re-fetch credentials:
   ```bash
   gcloud container clusters get-credentials <cluster-name> \
     --region <region> \
     --project <project-id>
   ```

2. Verify context:
   ```bash
   kubectl config current-context
   kubectl config use-context <correct-context>
   ```

## Component-Specific Issues

### Ingress NGINX

#### Issue: External IP Not Assigned

**Symptoms:**
```bash
$ kubectl get svc -n ingress-nginx
NAME                    TYPE           EXTERNAL-IP   PORT(S)
ingress-nginx-controller LoadBalancer   <pending>     80:31234/TCP
```

**Diagnosis:**
```bash
# Check service events
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Check load balancer quota
gcloud compute project-info describe --project=YOUR_PROJECT_ID | grep -i "load-balancer"
```

**Solution:**
1. Wait 5-10 minutes for GCP to provision load balancer
2. If still pending, check for quota issues
3. Check GCP Console → Network Services → Load Balancing
4. Try recreating the service:
   ```bash
   kubectl delete svc ingress-nginx-controller -n ingress-nginx
   helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
     -n ingress-nginx \
     --values helm/10-ingress-nginx/values.yaml
   ```

#### Issue: 502 Bad Gateway

**Symptoms:**
- HTTP requests to ingress return 502

**Diagnosis:**
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Check backend service
kubectl get endpoints -n openim
```

**Solution:**
1. Verify backend pods are running:
   ```bash
   kubectl get pods -n openim
   ```

2. Check service selectors match pod labels:
   ```bash
   kubectl describe svc <service-name> -n openim
   ```

3. Verify ingress configuration:
   ```bash
   kubectl describe ingress -n openim
   ```

### Redpanda (Kafka)

#### Issue: Pods Not Starting

**Symptoms:**
```
redpanda-0   0/1   CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n redpanda redpanda-0

# Check events
kubectl describe pod redpanda-0 -n redpanda

# Check persistent volume claims
kubectl get pvc -n redpanda
```

**Common Errors and Solutions:**

1. **Storage issues:**
   ```bash
   # Check if PVC is bound
   kubectl get pvc -n redpanda
   
   # If pending, check storage class
   kubectl get storageclass
   ```

2. **Memory limits:**
   ```bash
   # Increase memory in values.yaml
   resources:
     memory:
       container:
         max: 4Gi  # Increase this
   ```

3. **Port conflicts:**
   ```bash
   # Check if ports are already in use
   kubectl get svc --all-namespaces | grep 9092
   ```

#### Issue: Cannot Connect to Redpanda

**Symptoms:**
```
Error: connection refused to redpanda.redpanda.svc.cluster.local:9092
```

**Diagnosis:**
```bash
# Test from within cluster
kubectl run kafka-test --rm -it --restart=Never \
  --image=redpandadata/redpanda -- \
  rpk cluster info --brokers redpanda.redpanda.svc.cluster.local:9092

# Check service
kubectl get svc -n redpanda

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup redpanda.redpanda.svc.cluster.local
```

**Solution:**
1. Verify Redpanda is healthy:
   ```bash
   kubectl exec -it redpanda-0 -n redpanda -- rpk cluster health
   ```

2. Check network policies:
   ```bash
   kubectl get networkpolicies -n redpanda
   ```

3. Verify service endpoints:
   ```bash
   kubectl get endpoints -n redpanda
   ```

### Dragonfly (Redis)

#### Issue: Connection Refused

**Symptoms:**
```
Could not connect to Redis at dragonfly.dragonfly.svc.cluster.local:6379: Connection refused
```

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n dragonfly

# Check logs
kubectl logs -n dragonfly dragonfly-0

# Test connection
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping
```

**Solution:**
1. Verify pod is running:
   ```bash
   kubectl describe pod dragonfly-0 -n dragonfly
   ```

2. Check if port is correct:
   ```bash
   kubectl get svc -n dragonfly
   ```

3. Restart pod if needed:
   ```bash
   kubectl delete pod dragonfly-0 -n dragonfly
   ```

#### Issue: High Memory Usage

**Symptoms:**
- Pod gets OOMKilled
- Slow response times

**Diagnosis:**
```bash
# Check memory usage
kubectl top pod -n dragonfly

# Check Dragonfly memory info
kubectl exec -n dragonfly dragonfly-0 -- redis-cli INFO memory
```

**Solution:**
1. Increase memory limits in `helm/30-dragonfly/values.yaml`:
   ```yaml
   resources:
     limits:
       memory: 8Gi  # Increase based on needs
   dragonfly:
     maxMemory: 7168  # In MB, leave some headroom
   ```

2. Implement eviction policy:
   ```yaml
   # Add to dragonfly args in values.yaml
   - --maxmemory-policy=allkeys-lru
   ```

3. Upgrade the release:
   ```bash
   helm upgrade dragonfly helm/30-dragonfly -n dragonfly
   ```

### SeaweedFS

#### Issue: S3 API Not Accessible

**Symptoms:**
```
Could not connect to the endpoint URL: http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333
```

**Diagnosis:**
```bash
# Check filer pods
kubectl get pods -n seaweedfs -l app.kubernetes.io/component=filer

# Check filer logs
kubectl logs -n seaweedfs -l app.kubernetes.io/component=filer

# Test from within cluster
kubectl run s3-test --rm -it --restart=Never --image=amazon/aws-cli -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  s3 ls
```

**Solution:**
1. Verify filer service is up:
   ```bash
   kubectl get svc -n seaweedfs seaweedfs-filer
   ```

2. Check if S3 is enabled in values.yaml:
   ```yaml
   filer:
     s3:
       enabled: true
   ```

3. Verify S3 configuration:
   ```bash
   kubectl logs -n seaweedfs -l app.kubernetes.io/component=filer | grep -i s3
   ```

#### Issue: Volume Servers Not Starting

**Symptoms:**
```
seaweedfs-volume-0   0/1   CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check volume pod logs
kubectl logs -n seaweedfs seaweedfs-volume-0

# Check PVCs
kubectl get pvc -n seaweedfs
```

**Solution:**
1. Check storage availability:
   ```bash
   kubectl get pv
   kubectl describe pvc -n seaweedfs
   ```

2. Verify storage size is available:
   ```bash
   # Check node disk space
   kubectl get nodes -o json | jq '.items[] | {name:.metadata.name, allocatable:.status.allocatable}'
   ```

3. Reduce volume size if needed in `helm/40-seaweedfs/values.yaml`:
   ```yaml
   volume:
     dataDirs:
       - size: 20Gi  # Reduce if needed
   ```

### OpenIM

#### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```
openim-api-xxx   0/1   CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n openim openim-api-xxx

# Check previous logs if pod restarted
kubectl logs -n openim openim-api-xxx --previous

# Check events
kubectl describe pod -n openim openim-api-xxx
```

**Common Errors:**

1. **Database Connection Failed:**
   ```
   Error: Failed to connect to MySQL
   ```
   
   **Solution:**
   ```bash
   # Verify MySQL is running
   kubectl get pods -n openim -l app=mysql
   
   # Test connection
   kubectl run mysql-test --rm -it --restart=Never --image=mysql:8.0 -n openim -- \
     mysql -h openim-mysql -u openIM -popenIM123 -e "SHOW DATABASES;"
   
   # Check credentials in values.yaml
   ```

2. **Kafka Connection Failed:**
   ```
   Error: Failed to connect to Kafka broker
   ```
   
   **Solution:**
   ```bash
   # Verify Redpanda is accessible
   kubectl exec -it redpanda-0 -n redpanda -- rpk cluster info
   
   # Check broker addresses in values.yaml
   kafka:
     external:
       brokers:
         - "redpanda.redpanda.svc.cluster.local:9092"
   ```

3. **Redis Connection Failed:**
   ```
   Error: Failed to connect to Redis
   ```
   
   **Solution:**
   ```bash
   # Test Dragonfly connection
   kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
     redis-cli -h dragonfly.dragonfly.svc.cluster.local ping
   
   # Check host in values.yaml
   redis:
     external:
       host: "dragonfly.dragonfly.svc.cluster.local"
   ```

4. **S3/MinIO Connection Failed:**
   ```
   Error: Failed to connect to object storage
   ```
   
   **Solution:**
   ```bash
   # Verify SeaweedFS S3 is accessible
   kubectl run s3-test --rm -it --restart=Never --image=amazon/aws-cli -- \
     --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
     s3 ls
   
   # Check endpoint in values.yaml
   # Verify bucket exists
   ```

## Connectivity Issues

### Issue: Service to Service Communication Failed

**Symptoms:**
- Pods cannot reach other services
- DNS resolution fails

**Diagnosis:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup <service>.<namespace>.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nc -zv <service>.<namespace>.svc.cluster.local <port>

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solution:**
1. Verify service exists:
   ```bash
   kubectl get svc -n <namespace>
   ```

2. Check service endpoints:
   ```bash
   kubectl get endpoints -n <namespace> <service>
   ```

3. Verify network policies:
   ```bash
   kubectl get networkpolicies --all-namespaces
   ```

4. Restart CoreDNS if needed:
   ```bash
   kubectl rollout restart deployment -n kube-system coredns
   ```

## Performance Issues

### Issue: High API Latency

**Symptoms:**
- Slow API responses
- Timeouts

**Diagnosis:**
```bash
# Check pod resource usage
kubectl top pods -n openim

# Check node resource usage
kubectl top nodes

# Check for pod throttling
kubectl describe pod -n openim <pod> | grep -i throttl

# Check API logs for slow queries
kubectl logs -n openim -l app=openim-api | grep -i "slow"
```

**Solution:**
1. Scale up API pods:
   ```bash
   kubectl scale deployment openim-api -n openim --replicas=5
   ```

2. Increase resource limits:
   ```yaml
   # In helm/90-openim/values.yaml
   api:
     resources:
       limits:
         cpu: 2000m
         memory: 2Gi
   ```

3. Check database performance:
   ```bash
   # Connect to MySQL
   kubectl exec -it -n openim openim-mysql-0 -- mysql -u root -p
   
   # Check slow queries
   SHOW GLOBAL STATUS LIKE 'Slow_queries';
   
   # Enable slow query log
   SET GLOBAL slow_query_log = 'ON';
   SET GLOBAL long_query_time = 1;
   ```

4. Check cache hit rate:
   ```bash
   kubectl exec -n dragonfly dragonfly-0 -- redis-cli INFO stats | grep hit_rate
   ```

### Issue: High Memory Usage

**Symptoms:**
- Pods getting OOMKilled
- Cluster running out of memory

**Diagnosis:**
```bash
# Check memory usage by pod
kubectl top pods --all-namespaces --sort-by=memory

# Check memory usage by node
kubectl top nodes

# Check for memory leaks
kubectl logs -n <namespace> <pod> | grep -i "memory\|oom"
```

**Solution:**
1. Identify memory-hungry pods
2. Increase memory limits or optimize application
3. Add more nodes or use larger machine types:
   ```bash
   # Update envs/dev.tfvars
   machine_type = "e2-standard-8"  # More memory
   ```

4. Enable swap on nodes (not recommended for production)

## Storage Issues

### Issue: Persistent Volume Claims Pending

**Symptoms:**
```bash
$ kubectl get pvc -n <namespace>
NAME          STATUS    VOLUME   CAPACITY
data-pod-0    Pending
```

**Diagnosis:**
```bash
# Describe PVC
kubectl describe pvc -n <namespace> data-pod-0

# Check storage classes
kubectl get storageclass

# Check available storage
kubectl get pv
```

**Solution:**
1. Verify storage class exists:
   ```bash
   kubectl get storageclass standard
   ```

2. Check if storage quota is exceeded:
   ```bash
   gcloud compute project-info describe --project=YOUR_PROJECT_ID | grep -i disk
   ```

3. Create storage class if missing:
   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: standard
   provisioner: kubernetes.io/gce-pd
   parameters:
     type: pd-standard
   ```

### Issue: Disk Full

**Symptoms:**
- Pods failing with disk pressure
- Cannot write to persistent volumes

**Diagnosis:**
```bash
# Check disk usage on nodes
kubectl get nodes -o json | \
  jq '.items[] | {name:.metadata.name, disk:.status.allocatable."ephemeral-storage"}'

# Check pod disk usage
kubectl exec -it -n <namespace> <pod> -- df -h
```

**Solution:**
1. Clean up unused images:
   ```bash
   # On each node (requires SSH)
   gcloud compute ssh <node-name> -- docker system prune -af
   ```

2. Increase disk size:
   ```bash
   # Update envs/dev.tfvars
   disk_size_gb = 200  # Increase
   
   # Apply changes
   cd tofu/
   tofu apply -var-file=../envs/dev.tfvars
   ```

3. Add more nodes
4. Implement disk cleanup automation

## Security Issues

### Issue: RBAC Permission Denied

**Symptoms:**
```
Error: User "xxx" cannot list pods in namespace "yyy"
```

**Solution:**
```bash
# Create role binding
kubectl create rolebinding <name> \
  --clusterrole=view \
  --user=<user-email> \
  --namespace=<namespace>

# Or cluster-wide
kubectl create clusterrolebinding <name> \
  --clusterrole=view \
  --user=<user-email>
```

### Issue: Image Pull Errors

**Symptoms:**
```
ErrImagePull
ImagePullBackOff
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod -n <namespace> <pod>

# Check image exists
docker pull <image-name>
```

**Solution:**
1. Verify image name and tag
2. Check if image is public or requires authentication
3. Create image pull secret if needed:
   ```bash
   kubectl create secret docker-registry regcred \
     --docker-server=<registry> \
     --docker-username=<user> \
     --docker-password=<password> \
     --namespace=<namespace>
   ```

## General Debugging Tips

### Enable Debug Logging

```bash
# For OpenIM components
kubectl set env deployment/openim-api -n openim LOG_LEVEL=debug

# For Redpanda
kubectl exec -it redpanda-0 -n redpanda -- \
  rpk cluster config set log_level debug
```

### Use Debug Containers

```bash
# Create debug pod with network tools
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Create debug pod with specific tools
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

### Check Resource Events

```bash
# Get all events sorted by time
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n <namespace> --watch
```

### Force Pod Restart

```bash
# Delete pod (StatefulSet/Deployment will recreate)
kubectl delete pod -n <namespace> <pod>

# Rolling restart
kubectl rollout restart deployment/statefulset -n <namespace> <name>
```

## Getting Help

If issues persist:

1. **Check component documentation:**
   - OpenIM: https://github.com/openimsdk/open-im-server
   - Redpanda: https://docs.redpanda.com/
   - Dragonfly: https://www.dragonflydb.io/docs
   - SeaweedFS: https://github.com/seaweedfs/seaweedfs/wiki

2. **Search GitHub issues** for similar problems

3. **Enable debug logging** and collect logs

4. **Check GKE documentation** for platform-specific issues

5. **Open an issue** with:
   - Full error messages
   - Component versions
   - Steps to reproduce
   - Relevant logs and configurations

---

**Pro Tip:** Create a debug checklist for your team with the most common issues and their solutions specific to your deployment.
