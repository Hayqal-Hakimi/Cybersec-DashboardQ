# =============================================================================
# S3 BUCKET — Frontend Static Hosting
# =============================================================================
# Hosting static site untuk React SPA.
# Bucket dikonfigurasi untuk public read via bucket policy + OAC dari CloudFront.

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend"

  # Force destroy membenarkan terraform destroy walaupun bucket tidak kosong
  # (berguna untuk dev/sandbox — set false untuk production)
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
  }
}

# =============================================================================
# S3 BUCKET WEBSITE CONFIGURATION
# =============================================================================
resource "aws_s3_bucket_website_configuration" "hosting" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # React SPA handle routing sendiri
  }
}

# =============================================================================
# S3 BUCKET PUBLIC ACCESS BLOCK
# =============================================================================
# Kesemua block_access = false untuk benarkan public read.
# Keselamatan terletak pada bucket policy + CloudFront OAC, bukan block public access.
resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# =============================================================================
# S3 BUCKET POLICY — Public Read for CloudFront OAC
# =============================================================================
# Membenarkan akses public read untuk kandungan statik.
# NOTE: Dalam production, gantikan Principal dengan CloudFront OAC untuk
# akses yang lebih selamat (bucket hanya accessible via CloudFront).
data "aws_iam_policy_document" "frontend_public_read" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_public_read.json
}