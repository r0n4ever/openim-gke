# Redpanda - Kafka API Compatible Streaming Platform

This directory contains the Helm values for Redpanda, which replaces Apache Kafka as the message queue system for OpenIM.

## Why Redpanda?

**Advantages over Kafka:**
- **Simpler Architecture**: Single binary, no ZooKeeper dependency
- **Lower Resource Usage**: Requires less CPU and memory
- **Kafka API Compatible**: Drop-in replacement, no application code changes
- **Better Performance**: Optimized for modern hardware and cloud environments
- **Built-in Features**: Schema Registry and HTTP Proxy included

**Trade-offs:**
- Smaller ecosystem compared to Kafka
- Newer technology (less mature)
- For very large deployments (100+ brokers), Kafka might be more battle-tested

## Installation

```bash
# Add the Redpanda Helm repository
helm repo add redpanda https://charts.redpanda.com
helm repo update

# Install Redpanda
helm install redpanda redpanda/redpanda \
  --namespace redpanda --create-namespace \
  --values helm/20-redpanda/values.yaml
```

## Verification

```bash
# Check Redpanda pods
kubectl get pods -n redpanda

# Check Redpanda cluster status
kubectl exec -it redpanda-0 -n redpanda -- rpk cluster info

# Test topic creation
kubectl exec -it redpanda-0 -n redpanda -- rpk topic create test-topic

# List topics
kubectl exec -it redpanda-0 -n redpanda -- rpk topic list
```

## Connection Information

For OpenIM configuration:

```yaml
kafka:
  addr: 
    - redpanda.redpanda.svc.cluster.local:9092
  
  # Internal service DNS (for pod-to-pod communication)
  # redpanda-0.redpanda.redpanda.svc.cluster.local:9092
  # redpanda-1.redpanda.redpanda.svc.cluster.local:9092
  # redpanda-2.redpanda.redpanda.svc.cluster.local:9092
```

## Monitoring

Redpanda exposes Prometheus metrics on port 9644:

```bash
# Port-forward to access metrics locally
kubectl port-forward -n redpanda redpanda-0 9644:9644

# Access metrics at http://localhost:9644/metrics
```

## Configuration Notes

- **Replicas**: 3 brokers for production reliability
- **Storage**: 10Gi per broker (adjust based on retention needs)
- **Authentication**: Disabled for simplicity (enable for production)
- **Schema Registry**: Enabled for data validation

## Troubleshooting

```bash
# View Redpanda logs
kubectl logs -n redpanda redpanda-0

# Execute Redpanda admin commands
kubectl exec -it redpanda-0 -n redpanda -- rpk cluster status

# Check resource usage
kubectl top pods -n redpanda
```

## Production Considerations

**TODO for production:**
1. Enable SASL authentication
2. Configure TLS encryption
3. Set up tiered storage for cost optimization
4. Adjust retention policies based on workload
5. Configure monitoring and alerting
6. Set up regular backups

## Next Steps

After Redpanda is running, proceed to install Dragonfly (30-dragonfly).
