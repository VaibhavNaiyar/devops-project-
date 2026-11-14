output "app_url" {
  description = "CampusDesk through the load balancer"
  value       = "http://${aws_lb.app.dns_name}"
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "app_server_ips" {
  value = aws_instance.app[*].public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "dynamodb_table" {
  value = aws_dynamodb_table.requests.name
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${var.project}"
}

output "ssh_jenkins" {
  value = "ssh -i ~/.ssh/${var.project}.pem ubuntu@${aws_instance.jenkins.public_ip}"
}

output "github_webhook_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080/github-webhook/"
}
