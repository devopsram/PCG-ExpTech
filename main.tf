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

resource "aws_route_table_association" "app1_public_association" {
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.subnets[0].id
}

resource "aws_route_table_association" "app2_public_association" {
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
## }



# Launch Configuration for ECS Instances
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-launch-template-"
  image_id      = "ami-0c7af5fe939f2677f" # Replace with a valid ECS-optimized AMI ID
  instance_type = "t2.micro"              # Adjust instance type as needed
  key_name = "ecsInstance"

  network_interfaces {
    security_groups = [aws_security_group.app-sg.id]
    subnet_id       = aws_subnet.subnets[0].id # Use the first subnet from the list
  }
  # iam_instance_profile {
  #  name = "ecsInstanceRole"
  # }
  
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
  vpc_zone_identifier = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id]
  

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
 subnets            = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id]

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


# Define the ECS Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = "service-task"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "public.ecr.aws/f9n5f1l7/dgs:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

## ECS service

resource "aws_ecs_service" "ecs_service" {
 name            = "my-ecs-service"
 cluster         = aws_ecs_cluster.ecs_cluster.id
 task_definition = aws_ecs_task_definition.task.arn
 desired_count   = 2

 network_configuration {
   subnets         = [aws_subnet.subnets[0].id]
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

