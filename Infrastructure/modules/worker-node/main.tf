resource "aws_launch_template" "worker_lt" {
  name_prefix   = "${var.cluster_name}-worker-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "my-k8s-cluster-worker-node"

    }
  }
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/templates/worker-cloud-init.sh.tpl", {
    common_prereqs_script = file("${path.root}/scripts/common-k8s-prereqs.sh.tpl"),
    kubeadm_join_command  = var.kubeadm_join_command,
    kubeconfig_content    = var.kubeconfig_content,
    ansible_user          = var.ansible_user
    fixed_node_name       = "worker" 
  }))
  block_device_mappings {
    device_name = "/dev/xvda" # or /dev/sda1 depending on your AMI
    ebs {
      volume_size           = 20
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 2
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    type_node   = "worker"
    environment = "kubernetes"

  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                = "${var.cluster_name}-worker-asg"
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = var.desired_worker_count
  min_size            = var.min_worker_cpu_count
  max_size            = var.max_worker_cpu_count
  desired_capacity_type="vcpu"
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy = "capacity-optimized"
      
        
  }
  launch_template {
    launch_template_specification {
      launch_template_id = aws_launch_template.worker_lt.id
      version            = aws_launch_template.worker_lt.latest_version
    }
    override {
      instance_requirements {
        vcpu_count {
          min = local.worker.autoscale.min_vcpu_count
          max = local.worker.autoscale.max_vcpu_count
        }
        memory_mib {
          min = local.worker.autoscale.min_memory_mib
          max = local.worker.autoscale.max_memory_mib
        }
      }
    }
    }
  }
  
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 60
    }
    triggers = ["launch_template"]



  }
}
