# IAM role for DMS VPC management
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "dms.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "dms-vpc-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# IAM role for DMS CloudWatch Logs
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "dms.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "dms-cloudwatch-logs-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_role" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}
