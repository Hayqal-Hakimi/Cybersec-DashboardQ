# ---------------------------------------------------------------------------
# Core Infrastructure Variables
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project — used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "ap-southeast-1"
}

variable "instance_type" {
  description = "EC2 instance type for the backend server"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_port" {
  description = "Application port exposed on the backend server"
  type        = number
  default     = 5000
}

variable "root_volume_size" {
  description = "Size in GB of the root EBS volume"
  type        = number
  default     = 20
}

variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch detailed monitoring on EC2 (1-minute interval)"
  type        = bool
  default     = false
}

variable "nodejs_version" {
  description = "Node.js version to install on the instance"
  type        = number
  default     = 20
}

variable "ssh_key_path" {
  description = "Local path to the SSH public key for EC2 key pair"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "db_instance_class" {
  description = "RDS instance class for the database"
  type        = string
  default     = "db.t3.micro"
}

variable "domain_name" {
  description = "Custom domain name (empty string means no custom domain)"
  type        = string
  default     = ""
}

variable "office_ip" {
  description = "Office IP for restricted access (e.g., SSH). Leave empty for 0.0.0.0/0"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "alarm_evaluation_periods" {
  description = "Number of evaluation periods for CloudWatch alarms"
  type        = number
  default     = 3
}

variable "alarm_period_seconds" {
  description = "Period in seconds for CloudWatch alarm evaluation"
  type        = number
  default     = 300
}

variable "alarm_error_threshold" {
  description = "Error count threshold (e.g., 5xx) before alarm triggers"
  type        = number
  default     = 10
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization percentage threshold"
  type        = number
  default     = 80
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications (empty means no notifications)"
  type        = string
  default     = ""
}