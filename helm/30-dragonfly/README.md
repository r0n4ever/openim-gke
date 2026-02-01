# Dragonfly - Redis API Compatible In-Memory Store

This directory contains a minimal custom Helm chart for Dragonfly, a modern Redis replacement that provides better performance and lower memory usage while maintaining full Redis API compatibility.

## Why Dragonfly?

**Advantages over Redis:**
- **Better Performance**: Up to 25x faster throughput on some workloads
- **Lower Memory Usage**: ~30% less memory for the same dataset
- **Multi-threaded**: Utilizes multiple CPU cores efficiently
- **Redis API Compatible**: Drop-in replacement, no code changes needed
- **Simplified Operations**: Single binary, easier to manage

**Trade-offs:**
- Newer technology (less mature than Redis)
- Smaller community and ecosystem
- Some advanced Redis features might not be fully compatible

## Installation

Since Dragonfly lacks a mature official Helm chart, we provide a minimal custom chart:

```bash
# Install Dragonfly using the custom chart
helm install dragonfly helm/30-dragonfly \
  --namespace dragonfly --create-namespace
```

## Verification

```bash
# Check Dragonfly pods
kubectl get pods -n dragonfly

# Test Redis connection
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local ping

# Should return: PONG

# Test basic operations
kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local SET test "hello"

kubectl run redis-test --rm -it --restart=Never --image=redis:alpine -- \
  redis-cli -h dragonfly.dragonfly.svc.cluster.local GET test
```

## Connection Information

For OpenIM configuration:

```yaml
redis:
  address:
    - dragonfly.dragonfly.svc.cluster.local:6379
  
  # No password required by default (enable in production)
  # password: ""
```

## Monitoring

```bash
# Port-forward to access Dragonfly
kubectl port-forward -n dragonfly dragonfly-0 6379:6379

# Connect with redis-cli locally
redis-cli -h localhost -p 6379 INFO
```

## Configuration Notes

- **Replicas**: 2 instances for high availability
- **Memory**: 2Gi per instance (4Gi limit)
- **Persistence**: Enabled with 10Gi storage
- **Snapshots**: Saved every 5 minutes
- **Port**: 6379 (standard Redis port)

## Architecture

Dragonfly uses a StatefulSet with:
- Persistent volumes for data durability
- Pod anti-affinity for spreading across nodes
- Health checks for automatic recovery
- Resource limits for predictable performance

## Troubleshooting

```bash
# View Dragonfly logs
kubectl logs -n dragonfly dragonfly-0

# Check memory usage
kubectl exec -n dragonfly dragonfly-0 -- redis-cli INFO memory

# Check replication status (if configured)
kubectl exec -n dragonfly dragonfly-0 -- redis-cli INFO replication

# Monitor performance
kubectl top pods -n dragonfly
```

## Production Considerations

**TODO for production:**

1. **Enable Authentication**:
   ```yaml
   # Add to values.yaml
   dragonfly:
     password: "your-secure-password"
   ```

2. **Enable TLS**: Configure TLS certificates for encrypted connections

3. **Master-Replica Setup**: Configure replication for higher availability

4. **Adjust Memory**: Size based on your dataset and workload:
   ```yaml
   resources:
     limits:
       memory: 8Gi  # Adjust as needed
   dragonfly:
     maxMemory: 7168  # In MB
   ```

5. **Monitoring**: Set up Prometheus metrics and alerting

6. **Backup Strategy**: Configure regular snapshots and backup to GCS

## Scaling

Dragonfly scales vertically (more CPU/memory per instance) rather than horizontally like Redis Cluster:

```bash
# Update resources
helm upgrade dragonfly helm/30-dragonfly \
  --namespace dragonfly \
  --set resources.limits.memory=8Gi \
  --set dragonfly.maxMemory=7168
```

## Migration from Redis

Dragonfly is a drop-in replacement for Redis. To migrate:

1. Deploy Dragonfly alongside existing Redis
2. Update application configuration to point to Dragonfly
3. Use Redis MIGRATE or RDB snapshots to transfer data
4. Test thoroughly before removing Redis

## Next Steps

After Dragonfly is running, proceed to install SeaweedFS (40-seaweedfs).
