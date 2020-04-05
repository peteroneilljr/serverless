provider "aws" {
  region                  = var.region
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "personal"
}
variable "prefix" {
  default = "peter-serverless"
}
variable "region" {
  default = "us-west-2"
}

#################
# S3 buckets
#################
resource "aws_s3_bucket" "serverless_upload" {
  bucket = "${var.prefix}-sfp-upload"
  force_destroy = true
  cors_rule {
      allowed_headers = [
          "*",
      ]
      allowed_methods = [
          "GET",
          "POST",
      ]
      allowed_origins = [
          "*",
      ]
      expose_headers  = []
      max_age_seconds = 3000
  }
}
resource "aws_s3_bucket" "serverless_transcode" {
  bucket = "${var.prefix}-sfp-transcoder-bucket"
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "serverless" {
  bucket = aws_s3_bucket.serverless_transcode.id

  block_public_acls   = true
  ignore_public_acls = true
  block_public_policy = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "serverless" {
  bucket = aws_s3_bucket.serverless_transcode.id

  policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AddPerm",
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:GetObject",
			"Resource": "arn:aws:s3:::${aws_s3_bucket.serverless_transcode.bucket}/*"
		}
	]
}
POLICY
}

#################
# Elastic Transcoder
#################
resource "aws_elastictranscoder_pipeline" "serverless" {
  name         = "${var.prefix}-serverless-pipeline"

  input_bucket = aws_s3_bucket.serverless_upload.bucket
  output_bucket = aws_s3_bucket.serverless_transcode.bucket

  role         = aws_iam_role.transcoder.arn
}
#################
# Auth0
#################
provider "auth0" {
  domain=var.AUTH0_DOMAIN
  client_id=var.AUTH0_CLIENT_ID
  client_secret=var.AUTH0_CLIENT_SECRET
}

variable  "AUTH0_DOMAIN" {}
variable  "AUTH0_CLIENT_ID" {}
variable  "AUTH0_CLIENT_SECRET" {}

#################
# Lab 2
#################
provider "local" {}

resource "local_file" "website_config" {
    content     =  templatefile("./docker/lab2/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID })
    filename = "./docker/lab2/app/js/config.js"
}
#################
# Lab 3b
#################
resource "local_file" "website_config_3" {
    content     =  templatefile("./docker/lab3b/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID, apiBaseUrl = aws_api_gateway_deployment.deploy.invoke_url })
    filename = "./docker/lab3b/app/js/config.js"
}
#################
# Lab 4
#################
resource "local_file" "website_config_4" {
    content     =  templatefile("./docker/lab4a/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID, apiBaseUrl = aws_api_gateway_deployment.deploy.invoke_url })
    filename = "./docker/lab4a/app/js/config.js"
}
#################
# Lab 5
#################
resource "local_file" "website_config_5" {
    content     =  templatefile("./docker/lab5/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID, apiBaseUrl = aws_api_gateway_deployment.deploy.invoke_url })
    filename = "./docker/lab5/app/js/config.js"
}
