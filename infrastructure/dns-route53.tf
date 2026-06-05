# =============================================================================
# ROUTE53 HOSTED ZONE
# =============================================================================
# Hosted zone untuk domain utama. Nama domain ditetapkan melalui var.domain_name.

resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = {
    Name = "${var.project_name}-${var.environment}-hosted-zone"
  }
}

# =============================================================================
# ROUTE53 RECORDS
# =============================================================================

# Root domain (example.com) — A alias ke CloudFront
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

# WWW subdomain (www.example.com) — A alias ke CloudFront
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

# API subdomain (api.example.com) — A record ke Elastic IP backend
# NOTE: aws_eip.backend perlu diwujudkan dalam modul compute/network.
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"
  ttl     = 300

  records = [
    aws_eip.backend.public_ip,
  ]
}

# =============================================================================
# ROUTE53 HEALTH CHECK — API Endpoint
# =============================================================================
resource "aws_route53_health_check" "api" {
  fqdn              = "api.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-api-health-check"
  }

  # Optional: SNS notification apabila health check gagal
  # alarm_identifier {
  #   name   = "${var.project_name}-${var.environment}-api-health-alarm"
  #   region = var.aws_region
  # }
}