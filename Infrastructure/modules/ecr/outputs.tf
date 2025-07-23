
output "nginx_repo_url" {
  value = aws_ecr_repository.nginx_repo.repository_url
}

output "backend_repo_url" {
  value = aws_ecr_repository.backend_repo.repository_url
}

output "database_repo_url" {
  value = aws_ecr_repository.database_repo.repository_url
}

