# =============================================================================
# Secrets Manager — Security & Identity
# Region: ap-southeast-1 | Encryption at rest via AWS KMS
# =============================================================================

# -------------------------------------------------------------------
# DB Credentials Secret — stores RDS/MariaDB/PostgreSQL credentials
# Naming: environment/project-name/db-credentials
# Recovery window: 7 days (safe default to prevent accidental deletion)
# -------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}/${var.project_name}/db-credentials"
  recovery_window_in_days = 7

  # Encrypt at rest with AWS managed KMS key (default aws/secretsmanager)
  # Override with custom KMS key ARN if required:
  # kms_key_id = aws_kms_key.main.arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-credentials"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# -------------------------------------------------------------------
# DB Credentials Secret Version — initial secret values
# Values sourced from variables (not hardcoded)
# On rotate, Terraform creates a new version
# -------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}