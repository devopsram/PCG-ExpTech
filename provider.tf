terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 3.0"
    }
  }
} 

provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::970547357901:role/InfraCreationRole" # Replace with your role ARN
  }
}