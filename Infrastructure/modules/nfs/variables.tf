variable "subnet_ids" {
  description = "List of subnet IDs for the NFS server"
  type        = list(string)
  
}
variable "ami" {
  description = "AMI ID for the NFS server"
  type        = string
  
}
variable "instance_type" {
  description = "Instance type for the NFS server"
  type        = string
  default     = "c4.xlarge"
  
}
variable "vpc_id" {
    description = "VPC ID where the NFS server will be deployed"
    type        = string
  
}
variable "aws_key_name" {
    description = "value of the AWS key pair to use for the NFS server"
    type        = string
  
}