# SeaweedFS - S3 Compatible Object Storage

This directory contains the Helm values for SeaweedFS, which replaces MinIO as the S3-compatible object storage system for OpenIM.

## Why SeaweedFS?

**Advantages over MinIO:**
- **Simpler Architecture**: No complex distributed locking, easier to operate
- **Better Performance**: Optimized for many small files and high throughput
- **Lower Resource Usage**: More efficient memory and CPU utilization
- **S3 API Compatible**: Drop-in replacement for MinIO/AWS S3
- **Multiple Interfaces**: S3 API, native file system (FUSE), WebDAV

**Trade-offs:**
- Smaller ecosystem compared to MinIO
- Fewer enterprise features (IAM, encryption at rest)
- S3 compatibility is ~99% (some advanced features missing)
- Smaller community

## Architecture

SeaweedFS consists of three components:

1. **Master Server**: Manages volume allocation and metadata (3 replicas)
2. **Volume Server**: Stores actual data (3 replicas, 50Gi each)
3. **Filer**: Provides file system interface and S3 API (2 replicas)

## Installation

```bash
# Add the SeaweedFS Helm repository
helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
helm repo update

# Install SeaweedFS
helm install seaweedfs seaweedfs/seaweedfs \
  --namespace seaweedfs --create-namespace \
  --values helm/40-seaweedfs/values.yaml
```

## Verification

```bash
# Check all SeaweedFS pods
kubectl get pods -n seaweedfs

# Check master status
kubectl exec -n seaweedfs seaweedfs-master-0 -- weed shell -master=localhost:9333 cluster.status

# Check volume status
kubectl exec -n seaweedfs seaweedfs-master-0 -- weed shell -master=localhost:9333 volume.list

# Test S3 API access
kubectl run -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  --region=us-east-1 \
  s3 ls

# Create a test bucket
kubectl run -it --rm s3-test --image=amazon/aws-cli --restart=Never -- \
  --endpoint-url=http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333 \
  --region=us-east-1 \
  s3 mb s3://test-bucket
```

## Connection Information

For OpenIM configuration:

```yaml
object:
  enable: "minio"  # Keep as "minio" for S3 compatibility
  apiURL: "http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333"
  minio:
    endpoint: "http://seaweedfs-filer.seaweedfs.svc.cluster.local:8333"
    bucket: "openim"
    accessKeyID: "admin"
    secretAccessKey: "admin123"
    region: "us-east-1"  # Any value works
```

**⚠️ IMPORTANT**: Change the default credentials before production use!

## AWS CLI Configuration

To access from outside the cluster or for testing:

```bash
# Port-forward the S3 API
kubectl port-forward -n seaweedfs svc/seaweedfs-filer 8333:8333

# Configure AWS CLI
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key admin123
aws configure set default.region us-east-1

# Use AWS CLI with custom endpoint
aws --endpoint-url http://localhost:8333 s3 ls
aws --endpoint-url http://localhost:8333 s3 mb s3://openim
aws --endpoint-url http://localhost:8333 s3 cp file.txt s3://openim/
```

## Monitoring

SeaweedFS exposes metrics on various ports:

```bash
# Master metrics
kubectl port-forward -n seaweedfs seaweedfs-master-0 9333:9333
# Access: http://localhost:9333/metrics

# Volume metrics
kubectl port-forward -n seaweedfs seaweedfs-volume-0 8080:8080
# Access: http://localhost:8080/metrics

# Filer metrics
kubectl port-forward -n seaweedfs seaweedfs-filer-0 8888:8888
# Access: http://localhost:8888/metrics
```

## Configuration Notes

- **Master Replicas**: 3 for metadata high availability
- **Volume Replicas**: 3 servers, 50Gi storage each (150Gi total)
- **Filer Replicas**: 2 for S3 API high availability
- **Default Credentials**: admin/admin123 (CHANGE IN PRODUCTION!)
- **Storage Class**: standard (GKE default)

## Storage Capacity

With the default configuration:
- Total raw capacity: 150Gi (3 volume servers × 50Gi)
- Usable capacity depends on replication factor (configurable per bucket)
- Can scale by adding more volume servers

## Troubleshooting

```bash
# View logs for each component
kubectl logs -n seaweedfs seaweedfs-master-0
kubectl logs -n seaweedfs seaweedfs-volume-0
kubectl logs -n seaweedfs seaweedfs-filer-0

# Check cluster health
kubectl exec -n seaweedfs seaweedfs-master-0 -- weed master.status

# Check resource usage
kubectl top pods -n seaweedfs

# Debug S3 API issues
kubectl logs -n seaweedfs -l app.kubernetes.io/component=filer
```

## Production Considerations

**TODO for production:**

1. **Change Default Credentials**:
   ```yaml
   filer:
     s3:
       config: |
         {
           "identities": [
             {
               "name": "app",
               "credentials": [
                 {
                   "accessKey": "YOUR_ACCESS_KEY",
                   "secretKey": "YOUR_SECRET_KEY"
                 }
               ],
               "actions": ["Admin", "Read", "Write"]
             }
           ]
         }
   ```

2. **Enable TLS**: Configure SSL/TLS certificates for S3 API

3. **Set up Ingress**: For external access to S3 API

4. **Configure Backups**: 
   - Use volume snapshots
   - Replicate to GCS for disaster recovery

5. **Adjust Storage**: Size volumes based on your data requirements:
   ```bash
   helm upgrade seaweedfs seaweedfs/seaweedfs \
     --namespace seaweedfs \
     --set volume.dataDirs[0].size=100Gi
   ```

6. **Monitoring**: Set up Prometheus alerts for:
   - Volume space usage
   - Master availability
   - S3 API error rates

7. **Performance Tuning**: Adjust resources based on workload

## Scaling

To add more storage capacity:

```bash
# Increase volume size
helm upgrade seaweedfs seaweedfs/seaweedfs \
  --namespace seaweedfs \
  --set volume.dataDirs[0].size=100Gi

# Or add more volume servers
helm upgrade seaweedfs seaweedfs/seaweedfs \
  --namespace seaweedfs \
  --set volume.replicas=5
```

## Migration from MinIO

SeaweedFS S3 API is compatible with MinIO client and most S3 clients:

1. Deploy SeaweedFS alongside MinIO
2. Create buckets in SeaweedFS
3. Use `mc mirror` or `aws s3 sync` to copy data:
   ```bash
   mc mirror minio-server/bucket seaweedfs-server/bucket
   ```
4. Update application configuration
5. Verify data integrity
6. Decommission MinIO

## Next Steps

After SeaweedFS is running, proceed to install OpenIM (90-openim).
