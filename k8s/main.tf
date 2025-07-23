data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.root}/../Infrastructure/terraform.tfstate"
  }
}

resource "null_resource" "master_image_setup" {

  connection {
    type        = "ssh"
    host        = data.terraform_remote_state.infra.outputs.master_public_ip
    user        = data.terraform_remote_state.infra.outputs.ssh_user
    private_key = file("${path.root}/../Infrastructure/${data.terraform_remote_state.infra.outputs.private_key_path}")
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "../flaskapp-database"
    destination = "/home/ubuntu/app-code"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Logging into ECR...'",
      "aws ecr get-login-password --region ${data.terraform_remote_state.infra.outputs.region} | docker login --username AWS --password-stdin ${data.terraform_remote_state.infra.outputs.backend_repo_url}",
      "aws ecr get-login-password --region ${data.terraform_remote_state.infra.outputs.region} | docker login --username AWS --password-stdin ${data.terraform_remote_state.infra.outputs.backend_repo_url}",
      "echo 'Building and pushing backend image...'",
      "docker build -t backend-app /home/ubuntu/app-code/flaskapp",
      "docker tag backend-app:latest ${data.terraform_remote_state.infra.outputs.backend_repo_url}:latest",
      "docker push ${data.terraform_remote_state.infra.outputs.backend_repo_url}:latest",

      "echo 'Building and pushing database image...'",
      "docker build -t database-app /home/ubuntu/app-code/mysql",
      "docker tag database-app:latest ${data.terraform_remote_state.infra.outputs.database_repo_url}:latest",
      "docker push ${data.terraform_remote_state.infra.outputs.database_repo_url}:latest",
      
      "echo 'Image setup complete.'"
    ]
  }
}

provider "helm" {

kubernetes = {
    config_path ="${path.root}/../Infrastructure/${data.terraform_remote_state.infra.outputs.kubeconfig_file}"


  }

}

resource "helm_release" "mysql_db" {
  name       = "mysql-db"
  chart      = "${path.root}/../helm/helm packages/mysql-chart"
  namespace  = "backend"
  values     = [file("${path.root}/../helm/mysql/values.yaml")]

  depends_on = [kubernetes_namespace.app_ns, kubernetes_secret.ecr_regcred,null_resource.master_image_setup]
}


resource "helm_release" "flaskapp" {
  name       = "flaskapp"
  chart      = "${path.root}/../helm/helm packages/flaskapp"
  namespace  = "backend"
  values     = [file("${path.root}/../helm/flask/values.yaml")]
  depends_on = [helm_release.mysql_db]
  
}
data "aws_ecr_authorization_token" "token" {}

locals {
  target_namespaces = toset(["forntend", "backend"])

  docker_config_json = jsonencode({
    auths = {
      "${data.aws_ecr_authorization_token.token.proxy_endpoint}" = {
        "auth" = data.aws_ecr_authorization_token.token.authorization_token
      }
    }
  })
}


provider "kubernetes" {
  config_path ="${path.root}/../Infrastructure/${data.terraform_remote_state.infra.outputs.kubeconfig_file}"

}

resource "kubernetes_namespace" "app_ns" {
  for_each = local.target_namespaces

  metadata {
    name = each.key
  }

}

resource "kubernetes_secret" "ecr_regcred" {
  for_each = local.target_namespaces

  metadata {
    name      = "regcred"
    namespace = each.key
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.docker_config_json
  }

  depends_on = [kubernetes_namespace.app_ns]
}
