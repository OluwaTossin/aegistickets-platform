terraform {
  backend "s3" {
    bucket         = "aegis-tickets-tfstate-prod"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "aegis-tickets-tfstate-lock-prod"
    encrypt        = true
  }
}
