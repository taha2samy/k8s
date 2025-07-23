output "master_public_ip" {
  description = "Public IP of the Kubernetes Master node."
  value       = module.master_node.master_public_ip
}

# output "worker_public_ips" {
#   description = "Public IPs of the Kubernetes Worker nodes."
#   value       = module.worker_nodes.worker_public_ips
# }
output "kubeconfig_file" {
  value=data.local_file.kubeconfig_master_file.filename
}
output "kubeconfig_instructions" {
  description = "Instructions to configure kubectl on your local machine."
  value       = "To connect to your cluster, run: export KUBECONFIG=../kubeconfig-master.conf"
}
output "private_key_path" {
  value="${path.root}/${local_file.k8s_private_key_file.filename}"
}
output "ssh_user" {
  value = var.ssh_user
  
}
output "region" {
  value = var.aws_region
}

output "backend_repo_url" {
  value = module.ecr.backend_repo_url
}
output "database_repo_url" {
  value = module.ecr.database_repo_url
}
output "nginx_repo_url" {
  value = module.ecr.nginx_repo_url

  
}