
output "worker_public_ips" {
  description = "The public IP addresses of the Kubernetes worker nodes. This is dynamic."
  value       = data.aws_instances.workers.public_ips
}