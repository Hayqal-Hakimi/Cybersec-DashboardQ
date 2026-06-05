# ============================================================================
# 🔒 DISABLED FOR MVP — No database in CyberSec DashboardQ
# ============================================================================
# Re-enable when you add a database service (RDS, Aurora, etc.)
# DEPENDENCIES:
#   - RDS / Aurora resource must be created
#   - db_username, db_password, db_host, db_port, db_name variables needed
# ============================================================================
# Uncomment blocks below when ready:

# # =============================================================================
# # Secrets Manager — DB Credentials
# # Region: ap-southeast-1 | Encryption at rest via AWS KMS
# # =============================================================================
# 
# resource "aws_secretsmanager_secret" "db_credentials" {
#   name                    = "${var.environment}/${var.project_name}/db-credentials"
#   recovery_window_in_days = 7
# 
#   tags = {
#     Name        = "${var.project_name}-${var.environment}-db-credentials"
#     Environment = var.environment
#     Project     = var.project_name
#     ManagedBy   = "Terraform"
#   }
# }
# 
# resource "aws_secretsmanager_secret_version" "db_credentials" {
#   secret_id = aws_secretsmanager_secret.db_credentials.id
# 
#   secret_string = jsonencode({
#     username = var.db_username
#     password = var.db_password
#     host     = var.db_host
#     port     = var.db_port
#     dbname   = var.db_name
#   })
# }