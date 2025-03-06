resource "aws_vpc" "primary_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
      Name = "PCG-ECS-Dev"
  }
}

resource "aws_subnet" "subnets" {
  vpc_id = aws_vpc.primary_vpc.id
  count = length(var.subnet_cidrs)
  availability_zone = var.subnet_azs[count.index]
  cidr_block = var.subnet_cidrs[count.index]
  tags = {
    Name = var.subnet_names[count.index]
  }
}

resource "aws_security_group" "app-sg" {
  vpc_id = aws_vpc.primary_vpc.id

  # To allow traffic on ssh Port 22
  ingress {
    description = "Open ssh for all"
    from_port = local.ssh_port
    to_port = local.ssh_port
    protocol = local.tcp
    cidr_blocks = [ local.anywhere ]
  }

  #To allow traffc on port HTTP 80
  ingress {
    description = "Open HTTP for all"
    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tcp
    cidr_blocks = [ local.anywhere ]
  }

  #To allow traffic on Port HTTPS 443

  ingress {
    description = "Open HTTPS for all"
    from_port = local.https_port
    to_port = local.https_port
    protocol = local.tcp
    cidr_blocks = [ local.anywhere ]
  }

  #To access outside of VPC any 

  egress {
    description = "To access outside of VPC"
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = [ local.anywhere ]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "appsg"
  }

}

resource "aws_security_group" "dbsg" {
  vpc_id = aws_vpc.primary_vpc.id

  ingress {
    description = "Open PostgreSQL with in VPC"
    from_port = local.pg_port
    to_port = local.pg_port
    protocol = local.tcp
    cidr_blocks = [ var.vpc_cidr ]
  }

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = [ local.anywhere ]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "DB sg"
  }
  
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.primary_vpc.id
  tags = {
    Name = "Main-IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.primary_vpc.id
  tags = {
    Name = "public"
  }

  route {
    cidr_block = local.anywhere
    gateway_id = aws_internet_gateway.IGW.id
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.primary_vpc.id
  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "web1_public_association" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.subnets[0].id
}

resource "aws_route_table_association" "web2_public_association" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.subnets[1].id
}

# resource "aws_route_table_association" "db1_private_association" {
#   route_table_id = aws_route_table.private_rt.id
#   subnet_id = aws_subnet.subnets[2].id
# }

# resource "aws_route_table_association" "db2_private_association" {
#   route_table_id = aws_route_table.private_rt.id
#   subnet_id = aws_subnet.subnets[3].id
# }