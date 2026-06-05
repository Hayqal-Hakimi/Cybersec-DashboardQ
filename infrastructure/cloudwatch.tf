# =============================================================================
# CLOUDWATCH LOG GROUPS
# =============================================================================

# Log group untuk application logs (backend services)
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/${var.project_name}/${var.environment}/app"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-app-log-group"
  }
}

# Log group untuk access logs (frontend CDN / API access)
resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/${var.project_name}/${var.environment}/access"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-access-log-group"
  }
}

# =============================================================================
# CLOUDWATCH LOG METRIC FILTERS
# =============================================================================

# Filter: Analyze requests — track semua request yang masuk
resource "aws_cloudwatch_log_metric_filter" "analyze_requests" {
  name           = "${var.project_name}-${var.environment}-analyze-requests"
  pattern        = ""
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "AllRequests"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# Filter: Error 5xx — track server errors
resource "aws_cloudwatch_log_metric_filter" "error_5xx" {
  name           = "${var.project_name}-${var.environment}-error-5xx"
  pattern        = "\"[error]\" 5"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "Error5xxCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# Filter: Error 4xx — track client errors
resource "aws_cloudwatch_log_metric_filter" "error_4xx" {
  name           = "${var.project_name}-${var.environment}-error-4xx"
  pattern        = "\"[error]\" 4"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = "Error4xxCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# =============================================================================
# CLOUDWATCH METRIC ALARMS
# =============================================================================

# Alarm: High error rate — trigger bila 5XX error > 10 dalam 5 minit
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Error5xxCount"
  namespace           = "${var.project_name}/${var.environment}"
  period              = "300" # 5 minit
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This alarm triggers when 5XX errors exceed 10 in 5 minutes"
  treat_missing_data  = "notBreaching"

  alarm_actions = [
    var.alarm_sns_topic_arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-high-error-rate-alarm"
  }
}

# Alarm: High CPU — trigger bila CPU utilisation > 80%
# NOTE: Metric berasal dari CWAgent pada EC2 (memerlukan CloudWatch Agent dipasang).
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300" # 5 minit
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm triggers when CPU utilization exceeds 80%"
  treat_missing_data  = "notBreaching"

  alarm_actions = [
    var.alarm_sns_topic_arn,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-high-cpu-alarm"
  }
}

# =============================================================================
# CLOUDWATCH DASHBOARD
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: Error Rate Metrics (5XX + 4XX)
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["${var.project_name}/${var.environment}", "Error5xxCount", { stat = "Sum", label = "5XX Errors" }],
            ["${var.project_name}/${var.environment}", "Error4xxCount", { stat = "Sum", label = "4XX Errors" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Error Rate Metrics"
        }
      },

      # Widget 2: CPU Utilization
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "CPU %" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CPU Utilization"
        }
      },

      # Widget 3: Analyze Requests (All Requests count)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["${var.project_name}/${var.environment}", "AllRequests", { stat = "Sum", label = "Total Requests" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Analyze Requests"
        }
      },

      # Widget 4: Log Errors (5XX per minute)
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message\n| filter @message like /HTTP/1.1\" 5/\n| stats count() by bin(1m)"
          region = var.aws_region
          title  = "Log Errors (5XX per minute)"
        }
      },
    ]
  })
}