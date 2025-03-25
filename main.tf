resource "aws_vpc" "primary_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
      Name = "PCG-ECS-Dev"
  }
}

resource "aws_subnet" "pub_subnet1" {
  vpc_id = aws_vpc.primary_vpc.id
  #count = length(var.subnet_cidrs)
  availability_zone = var.subnet_azs[0]
  cidr_block = var.subnet_cidrs[0]
  tags = {
    Name = var.subnet_names[0]
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub_subnet2" {
  vpc_id = aws_vpc.primary_vpc.id
  #count = length(var.subnet_cidrs)
  availability_zone = var.subnet_azs[1]
  cidr_block = var.subnet_cidrs[1]
  tags = {
    Name = var.subnet_names[1]
  }
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet1" {
  vpc_id = aws_vpc.primary_vpc.id
  #count = length(var.subnet_cidrs)
  availability_zone = var.subnet_azs[2]
  cidr_block = var.subnet_cidrs[2]
  tags = {
    Name = var.subnet_names[2]
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id = aws_vpc.primary_vpc.id
  #count = length(var.subnet_cidrs)
  availability_zone = var.subnet_azs[3]
  cidr_block = var.subnet_cidrs[3]
  tags = {
    Name = var.subnet_names[3]
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

resource "aws_route_table_association" "app1_public_association" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.pub_subnet1.id
}

resource "aws_route_table_association" "app2_public_association" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.pub_subnet2.id
}

# #------------------SQL Server-------------------------------
# resource "aws_db_subnet_group" "main" {
#   name       = "my-db-subnet-group"
#   subnet_ids = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
 
#   tags = {
#     Name = "my-db-subnet-group"
#   }
# }
 
# resource "aws_db_instance" "my_rds_instance" {
#   allocated_storage    = 20
#   #db_name              = ""
#   storage_type         = "gp2"
#   engine               = "mysql"  # Modify for PostgreSQL, SQL Server, etc.
#   engine_version       = "8.0"    # Modify according to your needs
#   instance_class       = "db.t3.micro"  # Change instance class based on your needs
#   username             = "myuser"
#   password             = "mypassword"  # Use a more secure method for production (e.g., secrets manager)
#   parameter_group_name = "default.mysql8.0"  # Modify for other engines
#   db_subnet_group_name = aws_db_subnet_group.main.name
#   vpc_security_group_ids = [aws_security_group.dbsg.id]
 
#   multi_az             = true
#   publicly_accessible  = false
#   skip_final_snapshot  = true
 
#   tags = {
#     Name = "MyRDSInstance"
#   }
# }
 
 
# resource "aws_route_table_association" "db1_private_association" {
#   route_table_id = aws_route_table.private_rt.id
#   subnet_id = aws_subnet.subnets[2].id
# }

# resource "aws_route_table_association" "db2_private_association" {
#   route_table_id = aws_route_table.private_rt.id
#   subnet_id = aws_subnet.subnets[3].id
## }
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}
# Launch Configuration for ECS Instances
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-launch-template-"
  image_id      = "ami-08b5b3a93ed654d19" # Replace with a valid ECS-optimized AMI ID
  instance_type = "t3.medium"              # Adjust instance type as needed
  key_name = "ecsInstance"
  

  network_interfaces {
    security_groups = [aws_security_group.app-sg.id]
    subnet_id       = aws_subnet.pub_subnet1.id # Use the first subnet from the list
  }
   iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
   }
  
  block_device_mappings {
   device_name = "/dev/xvda"
   ebs {
     volume_size = 30
     volume_type = "gp2"
   }
 }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ECS-Cluster-Instance"
    }
  }

  user_data = filebase64("${path.module}/ecs.sh")
}

# Auto Scaling Group for ECS Instances
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity = 2
  max_size         = 2
  min_size         = 1

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.pub_subnet1.id, aws_subnet.pub_subnet2.id]
  

  tag {
   key                 = "AmazonECSManaged"
   value               = true
   propagate_at_launch = true
 
}
}

# Application Load balancer with Target group 
resource "aws_lb" "ecs_alb" {
 name               = "ecs-alb"
 internal           = false
 load_balancer_type = "application"
 security_groups    = [aws_security_group.app-sg.id]
 subnets            = [aws_subnet.pub_subnet1.id, aws_subnet.pub_subnet2.id]

 tags = {
   Name = "ecs-alb"
 }
}

resource "aws_lb_listener" "ecs_alb_listener" {
 load_balancer_arn = aws_lb.ecs_alb.arn
 port              = 80
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.ecs_tg.arn
 }
}

resource "aws_lb_target_group" "ecs_tg" {
 name        = "ecs-target-group"
 port        = 80
 protocol    = "HTTP"
 target_type = "ip"
 vpc_id      = aws_vpc.primary_vpc.id

 health_check {
   path = "/"
 }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "pcg-ecs-cluster"
}

#Capacity Providers

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
 name = "test1"

 auto_scaling_group_provider {
   auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

   managed_scaling {
     maximum_scaling_step_size = 1000
     minimum_scaling_step_size = 1
     status                    = "ENABLED"
     target_capacity           = 1
   }
 }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_provider" {
 cluster_name = aws_ecs_cluster.ecs_cluster.name

 capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

 default_capacity_provider_strategy {
   base              = 1
   weight            = 100
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
 }
}

# Create ECS Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect    = "Allow"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_policy_attachment" {
  name       = "ecs-task-execution-role-policy-attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/task-definition-dev"
  retention_in_days = 7
}

data "aws_iam_policy_document" "custom_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      aws_cloudwatch_log_group.ecs_log_group.arn
    ]
  }
}

resource "aws_iam_policy" "custom_policy" {
  name        = "CustomCloudWatchLogsPolicy"
  description = "Policy to create CloudWatch log groups for ECS"

  policy = data.aws_iam_policy_document.custom_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.custom_policy.arn
}

# Define the ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "awslogs-task"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "256"

  container_definitions = <<DEFINITION
    [
      {
        "logConfiguration": {
            "logDriver": "awslogs",
            "secretOptions": null,
            "options": {
              "awslogs-group": "/ecs/task-definition-dev",
              "awslogs-region": "us-east-1",
              "awslogs-stream-prefix": "ecs"
            }
          },
        "image": "hello-world",
        "name": "web",
        "portMappings": [
          {
            "containerPort": 80,
            "hostPort": 80
          }
        ] 
        }
    ]
    DEFINITION
}

## ECS service

resource "aws_ecs_service" "ecs_service" {
 name            = "my-ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.task.arn
 desired_count   = 1

 network_configuration {
   subnets         = [aws_subnet.pub_subnet1.id]
   security_groups = [aws_security_group.app-sg.id]
 }

 force_new_deployment = true
 placement_constraints {
   type = "distinctInstance"
 }

 capacity_provider_strategy {
   capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
   weight            = 100
 }

 load_balancer {
   target_group_arn = aws_lb_target_group.ecs_tg.arn
   container_name   = "web"
   container_port   = 80
 }

#  triggers = {
#    redeployment = timestamp()
#  }

 depends_on = [aws_autoscaling_group.ecs_asg]
}

