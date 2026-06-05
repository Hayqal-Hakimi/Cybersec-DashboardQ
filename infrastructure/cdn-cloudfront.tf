# =============================================================================
# CLOUDFRONT ORIGIN ACCESS CONTROL (OAC)
# =============================================================================
# OAC digunakan untuk restrict akses ke S3 bucket — hanya CloudFront
# dibenarkan akses, bukan public secara langsung.

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# =============================================================================
# CLOUDFRONT DISTRIBUTION — Frontend CDN
# =============================================================================
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${var.project_name}-${var.environment}-frontend"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment} frontend CDN"
  default_root_object = "index.html"

  # Hanya guna PriceClass_100 (US, Canada, Europe) untuk jimat kos
  # Guna PriceClass_200 atau PriceClass_All untuk coverage global
  price_class = "PriceClass_100"

  # Custom error response — redirect 403 ke index.html untuk SPA routing
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

  # Default cache behavior
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
    default_ttl            = 3600  # 1 jam
    max_ttl                = 86400 # 24 jam

    compress = true
  }

  # Restrictions (geo-restriction disabled)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL/TLS — guna CloudFront default certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Tags
  tags = {
    Name = "${var.project_name}-${var.environment}-cloudfront"
  }
}