terraform {
  backend "s3" {
    bucket         = "tf-state-aegistickets"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tf-locks-aegistickets"
    encrypt        = true
  }
}
