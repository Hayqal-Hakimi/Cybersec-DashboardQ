# ============================================================================
# 🔒 DISABLED FOR MVP — No custom domain yet
# ============================================================================
# Re-enable when you have a registered domain and set var.domain_name
# DEPENDENCIES:
#   - var.domain_name must be set (e.g., "cybersec-dashboardq.com")
#   - Route53 hosted zone must exist for the domain
#   - CloudFront distribution must be created (it already is)
# ============================================================================
# Uncomment blocks below when ready:

# # =============================================================================
# # ACM Certificate — TLS in Transit
# # Region: ap-southeast-1 | Validation: DNS via Route53 | Encryption: TLS
# # =============================================================================
# 
# resource "aws_acm_certificate" "main" {
#   domain_name       = var.domain_name
#   subject_alternative_names = ["*.${var.domain_name}"]
#   validation_method = "DNS"
# 
#   lifecycle {
#     create_before_destroy = true
#   }
# 
#   tags = {
#     Name        = "${var.project_name}-${var.environment}-acm-cert"
#     Environment = var.environment
#     Project     = var.project_name
#     ManagedBy   = "Terraform"
#   }
# }
# 
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       record = dvo.resource_record_value
#     }
#   }
# 
#   allow_overwrite = true
#   name            = each.value.name
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.main.zone_id
#   records         = [each.value.record]
#   ttl             = 60
# }
# 
# resource "aws_acm_certificate_validation" "main" {
#   certificate_arn         = aws_acm_certificate.main.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# 
#   timeouts {
#     create = "10m"
#   }
# }
# 
# data "aws_route53_zone" "main" {
#   name         = var.domain_name
#   private_zone = false
# }