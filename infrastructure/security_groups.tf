# =============================================================================
# Security Groups — Direct EC2 + CloudFront Architecture
# Region: ap-southeast-1 | Principle: Least Privilege | SSH via SSM only
# =============================================================================

# -------------------------------------------------------------------
# Backend (Application) Security Group
# Allows application port from internet (CloudFront will connect)
# NO SSH port 22 — use AWS Systems Manager (SSM) instead
# -------------------------------------------------------------------
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-${var.environment}-backend-sg"
  description = "Allow app traffic from internet (CloudFront origin), no SSH — use SSM"
  vpc_id      = aws_vpc.main.id

  # Ingress: Application port from anywhere (CloudFront IPs connect here)
  ingress {
    description = "Application traffic from internet (CloudFront)"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: all traffic to anywhere (for updates, API calls, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}