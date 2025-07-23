resource "local_file" "controlplane_group_vars" {
  depends_on = [module.master_node]

  filename = "${path.root}/../ansible/group_vars/role_controlplane_first_one.yaml"

  content = templatefile("${path.module}/templates/controlplane_vars.yaml.tpl", {
    nginx_repo_url    = module.ecr.nginx_repo_url
    backend_repo_url  = module.ecr.backend_repo_url
    database_repo_url = module.ecr.database_repo_url
  })
}
