provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "personal"
}
variable "prefix" {
  default = "peter-serverless"
}
resource "aws_s3_bucket" "serverless" {
  bucket = "${var.prefix}new-bucket"
}