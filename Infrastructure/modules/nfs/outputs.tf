output "nfs_private_ip" {
  value       = aws_spot_instance_request.cheap_worker.private_ip
  description = "Private IP of the NFS server (use this inside the same VPC)"
}

output "nfs_public_ip" {
  value       = aws_spot_instance_request.cheap_worker.public_ip
  description = "Public IP of the NFS server (use with caution)"
}

output "nfs_dns_name" {
  value       = aws_spot_instance_request.cheap_worker.public_dns
  description = "Public DNS name of the NFS server"
}

output "nfs_export_path" {
  value       = "/srv/nfs/shared"
  description = "The exported NFS path"
}
output "static_dns_name" {
  value       = aws_route53_record.nfs.name
  description = "The static DNS name for the NFS server"
  
}