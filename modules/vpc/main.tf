resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "igw_gtw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_gtw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_subnet" "pub_subnet-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_1
  availability_zone       = var.availability_zone-1
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.pub_subnet-1.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_subnet" "pub_subnet-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  availability_zone       = var.availability_zone-2
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.pub_subnet-2.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_subnet" "private_subnet-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_1
  availability_zone = var.availability_zone-1

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_2
  availability_zone = var.availability_zone-2

  tags = {
    Name = "private-subnet-2"
  }
}

resource "aws_subnet" "private_subnet-3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_3
  availability_zone = var.availability_zone-1

  tags = {
    Name = "private-subnet-3"
  }
}

resource "aws_subnet" "private_subnet-4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_4
  availability_zone = var.availability_zone-2

  tags = {
    Name = "private-subnet-4"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_subnet-1.id

  tags = {
    Name = "main-nat-gateway"
  }
  depends_on = [aws_internet_gateway.igw_gtw]
}

resource "aws_route_table" "private-app-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-app-rt"
  }
}

resource "aws_route_table" "private-db-rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-db-rt"
  }
}

resource "aws_route_table_association" "private-app-1" {
  subnet_id      = aws_subnet.private_subnet-1.id
  route_table_id = aws_route_table.private-app-rt.id
}

resource "aws_route_table_association" "private-app-2" {
  subnet_id      = aws_subnet.private_subnet-2.id
  route_table_id = aws_route_table.private-app-rt.id
}

resource "aws_route_table_association" "private-db-1" {
  subnet_id      = aws_subnet.private_subnet-3.id
  route_table_id = aws_route_table.private-db-rt.id
}

resource "aws_route_table_association" "private-db-2" {
  subnet_id      = aws_subnet.private_subnet-4.id
  route_table_id = aws_route_table.private-db-rt.id
}
