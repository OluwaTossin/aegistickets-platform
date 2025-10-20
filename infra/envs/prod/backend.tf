terraform {
  backend "s3" {
    bucket         = "tf-state-aegistickets"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tf-locks-aegistickets"
    encrypt        = true
  }
}
