# VPC
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dms-demo-vpc"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "dms-demo-private-${local.azs[count.index]}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "dms-demo-igw"
  }
}

# NAT Gateway (for DMS outbound connectivity)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "dms-demo-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private[0].id

  tags = {
    Name = "dms-demo-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "dms-demo-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# DB subnet group for Aurora
resource "aws_db_subnet_group" "aurora" {
  name       = "dms-demo-aurora-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "dms-demo-aurora-subnet-group"
  }
}

# DMS replication subnet group
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "dms-demo-subnet-group"
  replication_subnet_group_description = "DMS replication subnet group"
  subnet_ids                           = aws_subnet.private[*].id

  tags = {
    Name = "dms-demo-subnet-group"
  }
}
