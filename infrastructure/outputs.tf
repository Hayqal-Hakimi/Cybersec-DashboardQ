# ---------------------------------------------------------------------------
# Outputs — useful values after apply
# ---------------------------------------------------------------------------

# Human-readable summary of the deployment
output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value       = "Infrastructure '${var.project_name}-${var.environment}' deployed in ${var.aws_region}"
}

output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "ID of the public subnet in availability zone A"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "ID of the public subnet in availability zone B"
  value       = aws_subnet.public_b.id
}

output "backend_security_group_id" {
  description = "ID of the backend security group"
  value       = aws_security_group.backend_sg.id
}

output "backend_elastic_ip" {
  description = "Elastic IP address allocated to the backend server"
  value       = aws_eip.backend.public_ip
}

output "backend_api_url" {
  description = "Full URL to reach the backend API"
  value       = "http://${aws_eip.backend.public_ip}:${var.app_port}"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name — frontend + API access point"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "app_url" {
  description = "Main application URL (via CloudFront)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}