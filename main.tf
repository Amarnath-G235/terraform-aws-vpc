# VPC Resource Definition
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy = "default"

  tags = merge (
    var.common_tags,
    var.vpc_tags,
    {
        Name = local.resource_name
    }
  )
}

# Internet Gateway Resource Definition
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.igw_tags,
    {
        Name = local.resource_name 
    }
  )
}

# Public Subnet Resource Definition
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index] 
  # when instnace launch, public_ip will come automatically
  map_public_ip_on_launch = true
  tags = merge (
    var.common_tags,
    var.public_subnet_tags,
    {
        Name = "${local.resource_name}-public-${local.az_names[count.index]}"
    }
  )
}

# Private Subnet Resource Definition
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  
  tags = merge (
    var.common_tags,
    var.private_subnet_tags,
    {
        Name = "${local.resource_name}-private-${local.az_names[count.index]}"
    }
  )
}

# Database Subnet Resource Definition 
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]

  tags = merge (
    var.common_tags,
    var.database_subnet_tags,
    {
        Name = "${local.resource_name}-database-${local.az_names[count.index]}"
    }
  )
}

# Database subnet group for RDS
resource "aws_db_subnet_group" "default" {
  name       = local.resource_name
  subnet_ids = aws_subnet.database[*].id

  tags = merge (
    var.common_tags,
    var.db_subnet_group_tags,
    {
        Name = local.resource_name
    }
  )
}

# Elastic IP
resource "aws_eip" "nat" {
  domain   = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge (
    var.common_tags,
    var.nat_gateway_tags,
    {
        Name = local.resource_name
    }
  )
  
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

# Public Route Table creation
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.public_route_table_tags,
    {
      Name = "${local.resource_name}-public" # expense-dev-public
    }
  )
}

# Private Route Table creation
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.private_route_table_tags,
    {
      Name = "${local.resource_name}-private" # expense-dev-private
    }
  )
}

# Database Route Table creation
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge (
    var.common_tags,
    var.database_route_table_tags,
    {
      Name = "${local.resource_name}-database" # expense-dev-database
    }
  )
}

# Routes
resource "aws_route" "public" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0" # Internet connection 
  gateway_id                = aws_internet_gateway.main.id 
}

resource "aws_route" "private" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0" # Internet connection 
  nat_gateway_id            = aws_nat_gateway.main.id 
}

resource "aws_route" "database" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0" # Internet connection 
  nat_gateway_id            = aws_nat_gateway.main.id 
}

# Route tables association with Public, Private, Database subnets
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs) #2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs) #2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs) #2
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}



