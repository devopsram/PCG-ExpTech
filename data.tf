#Get the Existing IAM role
data "aws_iam_role" "infracreationrole"{
    name = "InfraCreationRole"
}