variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "The name of the Kubernetes Cluster."
  type        = string
  default     = "my-k8s-cluster"
}

variable "master_instance_type" {
  description = "The EC2 instance type for the Kubernetes master node."
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "The EC2 instance type for the Kubernetes worker nodes."
  type        = string
  default     = "t3.medium"
}
variable "desired_capacity" {
  description = "The desired number of worker CPUs in the Kubernetes cluster."
  type        = number
  default     = 7

}

variable "min_worker_cpu_count" {
  description = "The minimum number of worker CPUs in the Kubernetes cluster."
  type        = number
  default     = 7
}
variable "max_worker_cpu_count" {
  description = "The maximum number of worker CPUs in the Kubernetes cluster."
  type        = number
  default     = 14
}

variable "ssh_user" {
  description = "The SSH user for the chosen AMI (e.g., 'ubuntu' for Ubuntu, 'ec2-user' for Amazon Linux)."
  type        = string
  default     = "ubuntu"
}
variable "k8s_namespace" {
  description = "The Kubernetes namespace where resources will be created."
  type        = string
  default     = "default"
}