data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pcg-tf-state"
    key = "pcg/terraform.tfstate" // Path to state file within this bucket
    region = "us-east-1" // Change this to the appropriate region
  }
}