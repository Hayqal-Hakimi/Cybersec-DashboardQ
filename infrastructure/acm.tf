# =============================================================================
# ACM Certificate — TLS in Transit
# Region: ap-southeast-1 | Validation: DNS via Route53 | Encryption: TLS
# =============================================================================

# -------------------------------------------------------------------
# ACM Certificate — covers apex domain and wildcard subdomain
# create_before_destroy ensures zero downtime during renewal
# -------------------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-acm-cert"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# -------------------------------------------------------------------
# Route53 DNS Validation Records — one per DomainValidationOption
# for_each iterates over the certificate's domain_validation_options
# -------------------------------------------------------------------
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = [each.value.record]
  ttl             = 60
}

# -------------------------------------------------------------------
# ACM Certificate Validation — waits for DNS propagation
# Depends on Route53 validation records being created
# Timeout: 10 minutes for DNS propagation
# -------------------------------------------------------------------
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# -------------------------------------------------------------------
# Data source: Route53 zone (must exist)
# -------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}