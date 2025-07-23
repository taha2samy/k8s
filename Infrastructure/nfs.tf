

module "server_nfs" {
  source = "./modules/nfs"

  vpc_id       = module.vpc.vpc_id
  ami          = data.aws_ami.ubuntu.id
  subnet_ids   = module.vpc.public_subnet_ids
  aws_key_name = aws_key_pair.generated_key.key_name
}
output "nfs_namespace" {
  value       = module.server_nfs.nfs_export_path
  description = "The exported NFS path"

}
output "nfs_private_ip" {

  value       = module.server_nfs.nfs_private_ip
  description = "The private IP address of the NFS server"
}
output "nfs_public_ip" {

  value       = module.server_nfs.nfs_public_ip
  description = "The public IP address of the NFS server"

}