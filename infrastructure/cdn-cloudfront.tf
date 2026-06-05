# =============================================================================
# CLOUDFRONT ORIGIN ACCESS CONTROL (OAC)
# =============================================================================
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# =============================================================================
# CLOUDFRONT DISTRIBUTION — Frontend CDN + API Proxy
# =============================================================================
# Architecture:
#   - S3 origin: serves static frontend files (/, /index.html, /script.js, etc.)
#   - EC2 origin: proxies API calls to the backend (/analyze*, /health*)
#   - Both are served under the same CloudFront domain → same origin → no CORS

resource "aws_cloudfront_distribution" "frontend" {
  # ---- S3 ORIGIN (static files) ----
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${var.project_name}-${var.environment}-frontend"
  }

  # ---- EC2 ORIGIN (API backend) ----
  origin {
    domain_name = aws_eip.backend.public_ip
    origin_id   = "EC2-${var.project_name}-${var.environment}-backend"

    custom_origin_config {
      http_port              = var.app_port
      https_port             = 443
      origin_protocol_policy = "http-only"  # EC2 doesn't have SSL (yet)
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} — Frontend CDN + API Proxy"
  default_root_object = "index.html"

  # Hanya PriceClass_100 (US, Canada, Europe) untuk jimat kos
  price_class = "PriceClass_100"

  # Custom error response — redirect 403/404 ke index.html
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # ---- DEFAULT: S3 origin (static files) ----
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.project_name}-${var.environment}-frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    compress = true
  }

  # ---- API path: forward to EC2 backend ----
  ordered_cache_behavior {
    path_pattern     = "/analyze*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "EC2-${var.project_name}-${var.environment}-backend"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Authorization", "Content-Type"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    compress = false
  }

  ordered_cache_behavior {
    path_pattern     = "/health*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EC2-${var.project_name}-${var.environment}-backend"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    compress = false
  }

  # Restrictions (geo-restriction disabled)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL/TLS — CloudFront default certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}