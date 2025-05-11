locals {
  anywhere = "0.0.0.0/0"
  ssh_port = "22"
  http_port = "80"
  https_port = "443"
  pg_port = "5432"
  tcp = "TCP"
  policies = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  ]
}