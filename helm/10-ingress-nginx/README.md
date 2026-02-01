# Ingress NGINX - HTTP/HTTPS Entry Point

This directory contains the Helm values for the NGINX Ingress Controller, which serves as the entry point for all external traffic to the OpenIM cluster.

## Installation

```bash
# Add the ingress-nginx Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --values helm/10-ingress-nginx/values.yaml
```

## Verification

```bash
# Check the ingress controller pods
kubectl get pods -n ingress-nginx

# Get the external IP address (wait for EXTERNAL-IP to be assigned)
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Test the ingress controller
curl http://<EXTERNAL-IP>
```

## Configuration Notes

- **Replicas**: Set to 2 for high availability
- **Autoscaling**: Enabled with min 2, max 5 replicas
- **Load Balancer**: Creates a GCP External Load Balancer
- **Body Size**: Configured for 100MB to support file uploads
- **Timeouts**: Extended to 600s for long-running operations

## DNS Configuration

Once the Load Balancer is provisioned, update your DNS records:

```
openim.example.com      A    <EXTERNAL-IP>
*.openim.example.com    A    <EXTERNAL-IP>
```

## Next Steps

After ingress-nginx is running, proceed to install Redpanda (20-redpanda).
