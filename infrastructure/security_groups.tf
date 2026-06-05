# =============================================================================
# Security Groups - Security & Identity
# Region: ap-southeast-1 | Principle: Least Privilege | No SSH 0.0.0.0/0
# =============================================================================

# -------------------------------------------------------------------
# ALB Security Group — allows HTTPS (443) and HTTP (80) from internet
# -------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS inbound from internet, all outbound"
  vpc_id      = aws_vpc.main.id

  # Ingress: HTTPS from anywhere (TLS termination)
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: HTTP from anywhere (redirect to HTTPS)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: all traffic to anywhere
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# -------------------------------------------------------------------
# Backend (Application) Security Group — app_port only from ALB SG
# NO SSH port 22 — use AWS Systems Manager (SSM) instead
# -------------------------------------------------------------------
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-${var.environment}-backend-sg"
  description = "Allow app traffic from ALB only; no SSH open — use SSM"
  vpc_id      = aws_vpc.main.id

  # Ingress: Application port from ALB security group only
  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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

# -------------------------------------------------------------------
# Database Security Group — db_port only from Backend SG
# No public access, no SSH
# -------------------------------------------------------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Allow database traffic from backend tier only"
  vpc_id      = aws_vpc.main.id

  # Ingress: Database port from backend security group only
  ingress {
    description     = "Database traffic from backend"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # Egress: all traffic to anywhere
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}