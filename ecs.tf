# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "pcg-ecs-cluster"
}
# Launch Configuration for ECS Instances
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-launch-template-"
  image_id      = "ami-0c55b159cbfafe1f0" # Replace with a valid ECS-optimized AMI ID
  instance_type = "t2.micro"              # Adjust instance type as needed

  network_interfaces {
    security_groups = [data.terraform_remote_state.network.outputs.app_security_group_id.id]#[aws_security_group.ecs_sg.id]
    subnet_id       = data.terraform_remote_state.network.outputs.app1-subnet-id.id#var.subnet_ids[0] # Use the first subnet from the list
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ECS-Cluster-Instance"
    }
  }
}

# Auto Scaling Group for ECS Instances
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity = 1
  max_size         = 2
  min_size         = 1

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.terraform_remote_state.network.outputs.app1-subnet-id.id
 
}

# ECS Service Role
resource "aws_iam_role" "ecs_service_role" {
  name = "ecsServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
    }]
  })
}

# Attach Policy to ECS Service Role
resource "aws_iam_role_policy_attachment" "ecs_service_policy" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSServiceRolePolicy"
}

