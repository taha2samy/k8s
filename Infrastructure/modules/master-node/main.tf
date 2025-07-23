resource "aws_instance" "master" {
  ami           = var.ami_id
  iam_instance_profile = var.instance_profile_name
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/master-cloud-init.sh.tpl", {
    common_prereqs_script = file("${path.root}/scripts/common-k8s-prereqs.sh.tpl"),
    priority_classes_yaml = file("${path.module}/templates/priority-classes.yaml"),
    nfs_namespace_yaml    = file("${path.module}/templates/nfs/namespace.yaml"),
    nfs_csidriver_yaml = file("${path.module}/templates/nfs/csidriver.yaml"),
    nfs_deployment_yaml = templatefile("${path.module}/templates/nfs/deployment.yaml", {
      NFS_SERVER = var.nfs_server_dns,
      NFS_PATH   = var.nfs_export_path}),
    nfs_storageclass_yaml = file("${path.module}/templates/nfs/storageclass.yaml"),
    ECR_REGISTRY_URL = var.ecr_repository_url,
    ECR_REGION = var.region,
    ansible_user          = var.ansible_user,
    cluster_name = var.cluster_name
    
  })

  tags = {
    Name = "${var.cluster_name}-controlplane"
    type_node = "controlplane-first-one"
    environment = "kubernetes"
    

  }
  root_block_device {
  delete_on_termination = true
      volume_size           = 40
    volume_type           = "gp2"

}
}

resource "null_resource" "master_setup" {
  depends_on = [aws_instance.master]

  connection {
    type        = "ssh"
    host        = aws_instance.master.public_ip
    user        = var.ansible_user
    private_key = file(var.private_key_path)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "timeout 800 bash -c 'while [ ! -f /etc/kubernetes/admin.conf ]; do sleep 10; done'",
      "timeout 800 bash -c 'while ! sudo /usr/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes >/dev/null 2>&1; do sleep 10; done'",
      "echo 'Kubernetes master is ready.'"
    ]
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      ${var.ansible_user}@${aws_instance.master.public_ip} "sudo cat /etc/kubernetes/admin.conf" > ./kubeconfig-master.conf
    EOT
  }
      provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      ${var.ansible_user}@${aws_instance.master.public_ip} \
      "sudo /usr/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
    EOT
  }

  provisioner "local-exec" {
    command = <<EOT
      KUBEADM_JOIN_COMMAND=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      ${var.ansible_user}@${aws_instance.master.public_ip} "sudo kubeadm token create --print-join-command")
      echo "$KUBEADM_JOIN_COMMAND" > ./kubeadm_join_command
    EOT
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      ${var.ansible_user}@${aws_instance.master.public_ip} \
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf label node controlplane node-role.kubernetes.io/control-plane= --overwrite=true"
    EOT
  }
  

}