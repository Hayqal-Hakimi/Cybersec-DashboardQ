# =============================================================================
# S3 BUCKET — Frontend Static Hosting (OAC via CloudFront)
# =============================================================================
# Bucket is PRIVATE — only accessible via CloudFront Origin Access Control (OAC).
# No public read. No static website hosting (CloudFront handles serving).

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend"

  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# -------------------------------------------------------------------
# PRIVATE BUCKET — block all public access
# CloudFront OAC is the ONLY way to access this bucket
# -------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------------------------------------
# BUCKET POLICY — Allow CloudFront OAC only
# -------------------------------------------------------------------
data "aws_iam_policy_document" "frontend_oac" {
  statement {
    sid    = "AllowCloudFrontOAC"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_oac.json
}

# =============================================================================
# S3 BUCKET — Backend Code Storage
# =============================================================================
# Stores the backend application code as a tarball.
# EC2 downloads via IAM role on boot.

resource "aws_s3_bucket" "backend_code" {
  bucket = "${var.project_name}-${var.environment}-backend-code"

  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-code"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "backend_code_private" {
  bucket = aws_s3_bucket.backend_code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------------------------------------
# UPLOAD BACKEND CODE — via local-exec after bucket exists
# -------------------------------------------------------------------
resource "terraform_data" "upload_backend_code" {
  triggers_replace = [
    filesha1("${path.module}/../backend/app.py"),
    filesha1("${path.module}/../backend/requirements.txt"),
  ]

  provisioner "local-exec" {
    command = <<CMD
      cd '${path.module}/../backend'
      tar -czf /tmp/backend-${var.project_name}.tar.gz --exclude=venv .
      aws s3 cp /tmp/backend-${var.project_name}.tar.gz s3://${var.project_name}-${var.environment}-backend-code/backend.tar.gz
      rm -f /tmp/backend-${var.project_name}.tar.gz
    CMD
  }

  depends_on = [aws_s3_bucket.backend_code]
}