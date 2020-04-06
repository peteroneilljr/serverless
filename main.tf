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
  bucket = "${var.prefix}-acg-upload-videos"
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
  bucket = "${var.prefix}-acg-transcoded-videos"
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
resource "aws_s3_bucket_public_access_block" "serverless_transcode" {
  bucket = aws_s3_bucket.serverless_transcode.id

  block_public_acls   = true
  ignore_public_acls = true
  block_public_policy = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "serverless_transcode" {
  bucket = aws_s3_bucket.serverless_transcode.id

  policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "Make",
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:GetObject",
			"Resource": "${aws_s3_bucket.serverless_transcode.arn}/*"
		}
	]
}
POLICY
}

#################
# Elastic Transcoder
#################
resource "aws_elastictranscoder_pipeline" "serverless" {
  name         = "${var.prefix}-transcoder-pipeline"

  input_bucket = aws_s3_bucket.serverless_upload.bucket
  output_bucket = aws_s3_bucket.serverless_transcode.bucket

  role         = aws_iam_role.transcoder.arn
}
#################
# Auth0
#################

variable  "AUTH0_DOMAIN" {}
variable  "AUTH0_CLIENT_ID" {}
variable  "AUTH0_CLIENT_SECRET" {}

#################
# Firebase
#################

variable "FIREBASE_URL" {}

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
resource "local_file" "auth0_config" {
    content     =  templatefile("./docker/lab5/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID, apiBaseUrl = aws_api_gateway_deployment.deploy.invoke_url })
    filename = "./docker/lab5/app/js/config.js"
}
resource "local_file" "firebase_config" {
    content     =  templatefile("./docker/lab5/app/js/video-controller_template.js", { FIREBASE_AUTH = var.FIREBASE_AUTH })
    filename = "./docker/lab5/app/js/video-controller.js"
}
variable "FIREBASE_AUTH" {}

#################
# Host Site on S3
#################
resource "aws_s3_bucket" "host_site" {
  bucket = "${var.prefix}-acg-video-transcoder-site"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  force_destroy = true
  provisioner "local-exec" {
    when = destroy
    command = "aws s3 rm s3://${self.bucket} --recursive --profile personal"
  }
}
resource "aws_s3_bucket_public_access_block" "host_site" {
  bucket = aws_s3_bucket.host_site.id

  block_public_acls   = false
  ignore_public_acls = false
  block_public_policy = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "host_site" {
  bucket = aws_s3_bucket.host_site.id

  policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AddPerm",
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:GetObject",
			"Resource": "${aws_s3_bucket.host_site.arn}/*"
		}
	]
}
POLICY
}
resource "null_resource" "sync_host_site" {
  triggers = {
    firebase_config = fileexists("./docker/lab5/app/js/video-controller.js") ? filesha1("./docker/lab5/app/js/video-controller.js") : null
    auth0_config = fileexists("./docker/lab5/app/js/config.js") ? filesha1("./docker/lab5/app/js/config.js") : null
  }
  provisioner "local-exec" {
    command = "aws s3 sync ${abspath("./docker/lab5/app")} s3://${aws_s3_bucket.host_site.id} --profile personal"
  }
  depends_on = [local_file.firebase_config, local_file.auth0_config]
}

output "website_url" {
  value = "http://${aws_s3_bucket.host_site.website_endpoint}"
}
