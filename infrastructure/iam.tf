# =============================================================================
# IAM Roles & Policies — Security & Identity
# Region: ap-southeast-1 | Principle: Least Privilege
# =============================================================================

# -------------------------------------------------------------------
# IAM Role for EC2 instances — assume role by EC2 service
# -------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# -------------------------------------------------------------------
# Attach: AWS Systems Manager — agentless instance management
# No SSH port 22 required — SSM replaces SSH entirely
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -------------------------------------------------------------------
# Attach: CloudWatch Agent — metrics and logs publishing
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# -------------------------------------------------------------------
# Attach: Secrets Manager — read/write access for DB creds rotation
# -------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# -------------------------------------------------------------------
# IAM Instance Profile — attach to EC2 launch config/ASG
# -------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}