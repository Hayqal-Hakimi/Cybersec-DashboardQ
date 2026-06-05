# ============================================================================
# 🔒 DISABLED FOR MVP — No custom domain yet
# ============================================================================
# Re-enable when you have a registered domain and set var.domain_name
# DEPENDENCIES:
#   - var.domain_name must be set (e.g., "cybersec-dashboardq.com")
#   - ACM certificate must be created (see acm.tf)
#   - CloudFront distribution must be created (it already is)
# ============================================================================
# Uncomment blocks below when ready:

# # =============================================================================
# # ROUTE53 HOSTED ZONE
# # =============================================================================
# 
# resource "aws_route53_zone" "primary" {
#   name = var.domain_name
# 
#   tags = {
#     Name = "${var.project_name}-${var.environment}-hosted-zone"
#   }
# }
# 
# # Root domain (example.com) — A alias ke CloudFront
# resource "aws_route53_record" "root" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = var.domain_name
#   type    = "A"
# 
#   alias {
#     name                   = aws_cloudfront_distribution.frontend.domain_name
#     zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
# 
# # WWW subdomain (www.example.com) — A alias ke CloudFront
# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "www.${var.domain_name}"
#   type    = "A"
# 
#   alias {
#     name                   = aws_cloudfront_distribution.frontend.domain_name
#     zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
# 
# # API subdomain (api.example.com) — A record ke Elastic IP backend
# resource "aws_route53_record" "api" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "api.${var.domain_name}"
#   type    = "A"
#   ttl     = 300
# 
#   records = [
#     aws_eip.backend.public_ip,
#   ]
# }
# 
# # Route53 Health Check — API Endpoint
# resource "aws_route53_health_check" "api" {
#   fqdn              = "api.${var.domain_name}"
#   port              = 443
#   type              = "HTTPS"
#   resource_path     = "/health"
#   failure_threshold = 3
#   request_interval  = 30
# 
#   tags = {
#     Name = "${var.project_name}-${var.environment}-api-health-check"
#   }
# }