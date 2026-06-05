# ---------------------------------------------------------------------------
# EC2 — Backend Server Configuration
# Source: AWS Terraform Master Template (Notion) — 15-ec2-tf.md
# ---------------------------------------------------------------------------

# Data source: fetch latest Ubuntu 24.04 LTS AMI dynamically (cross-region safe)
# DO NOT hardcode AMI ID — they are region-specific
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH key pair — references public key from the developer's machine
resource "aws_key_pair" "backend_key" {
  key_name   = "${var.project_name}${var.environment}key"
  public_key = file(pathexpand(var.ssh_key_path))

  tags = {
    Name        = "${var.project_name}-${var.environment}-key"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Elastic IP — static public IP (survives instance stop/start)
resource "aws_eip" "backend" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eip"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Separate EIP association (deprecated `instance` attribute in aws_eip not used)
resource "aws_eip_association" "backend_assoc" {
  instance_id   = aws_instance.backend_server.id
  allocation_id = aws_eip.backend.id
}

# EC2 instance — the backend server
# NOTE: Security group (backend_sg) defined in security_groups.tf
# NOTE: IAM role & instance profile (ec2_role, ec2_profile) defined in iam.tf
resource "aws_instance" "backend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = aws_key_pair.backend_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  monitoring             = var.enable_detailed_monitoring

  # Root volume: gp3 (better IOPS than gp2, same price)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root-volume"
    }
  }

  # Bootstrap script — runs ONCE on first boot only
  # WARNING: user_data_replace_on_change must remain false (prevents rebuild)
  user_data = templatefile("${path.module}/userdata.sh", {
    project_name   = var.project_name
    environment    = var.environment
    nodejs_version = var.nodejs_version
  })
  user_data_replace_on_change = false

  tags = {
    Name        = "${var.project_name}-backend"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}