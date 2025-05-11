
# Create IAM Policy for Elastic IP Management
resource "aws_iam_policy" "elastic_ip_policy" {
  name        = "ElasticIPPolicy"
  description = "IAM policy to allow Elastic IP creation and management"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:AllocateAddress",
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DisassociateAddress",
          "ec2:ReleaseAddress"
        ],
        Resource = "*"
      }
    ]
  })
}

#Attach policies to IAM role
resource "aws_iam_policy_attachment" "attachelasticIPpolicy" {
  name = "iampolicyattachment"
  roles  = [data.aws_iam_role.infracreationrole.name]
  policy_arn = aws_iam_policy.elastic_ip_policy.arn

}



resource "aws_eip" "elastic_ip" {
}

resource "aws_nat_gateway" "private_nat" {
  allocation_id = aws_eip.elastic_ip.id
  subnet_id = aws_subnet.pub_subnet1.id
  tags = {
    Name = "NatForDB"
  }

}

resource "aws_route_table" "Nat_route_table" {
  vpc_id = aws_vpc.primary_vpc.id
  route {
    cidr_block = local.anywhere
    gateway_id = aws_nat_gateway.private_nat.id  
  } 
  tags = {
    Name = "Nat-Route-table"
  }
}

resource "aws_route_table_association" "assicuate_routetable_to_privatesubnet" {
  subnet_id = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.Nat_route_table.id
}



