data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tfremotestate-vpc"
    key = "state" // Path to state file within this bucket
    region = "us-east-1" // Change this to the appropriate region
  }
}