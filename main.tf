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
}
resource "aws_s3_bucket" "serverless-transcode" {
  bucket = "${var.prefix}-sfp-transcode"
  force_destroy = true
}
resource "aws_s3_bucket_public_access_block" "serverless" {
  bucket = aws_s3_bucket.serverless-transcode.id

  block_public_acls   = true
  ignore_public_acls = true
  block_public_policy = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "serverless" {
  bucket = aws_s3_bucket.serverless-transcode.id

  policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "AddPerm",
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:GetObject",
			"Resource": "arn:aws:s3:::${aws_s3_bucket.serverless-transcode.bucket}/*"
		}
	]
}
POLICY
}
  
#################
# IAM lambda transcoder role
#################
resource "aws_iam_role" "serverless_lambda" {
  name = "${var.prefix}-lambda-transcoder-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
}
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "lambda_execute" {
  role       = aws_iam_role.serverless_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}
resource "aws_iam_role_policy_attachment" "elastic_jobs_submitter" {
  role       = aws_iam_role.serverless_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticTranscoder_JobsSubmitter"
}
#################
# IAM Transcoder Role
#################
resource "aws_iam_role" "transcoder" {
  name = "${var.prefix}-transcoder-role"
  assume_role_policy = data.aws_iam_policy_document.assume_elastictranscoder.json

  force_detach_policies = true
}
data "aws_iam_policy_document" "assume_elastictranscoder" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elastictranscoder.amazonaws.com"]
    }
  }
}
resource "aws_iam_policy" "elastictranscoder" {
  name        = "${var.prefix}-elastictranscoder-default"
  path        = "/"
  description = "Copy of ElasticTranscoder default role"

  policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Sid":"1",
         "Effect":"Allow",
         "Action":[
            "s3:Get*",
            "s3:ListBucket",
            "s3:Put*",
            "s3:*MultipartUpload*"
         ],
         "Resource":"*"
      },
      {
         "Sid":"2",
         "Effect":"Allow",
         "Action":"sns:Publish",
         "Resource":"*"
      },
      {
         "Sid":"3",
         "Effect":"Deny",
         "Action":[
            "sns:*Permission*",
            "sns:*Delete*",
            "sns:*Remove*",
            "s3:*Policy*",
            "s3:*Delete*"
         ],
         "Resource":"*"
      }
   ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "elastictranscoder" {
  role       = aws_iam_role.transcoder.name
  policy_arn = aws_iam_policy.elastictranscoder.arn
}

#################
# Elastic Transcoder
#################
resource "aws_elastictranscoder_pipeline" "serverless" {
  name         = "${var.prefix}-serverless-pipeline"

  input_bucket = aws_s3_bucket.serverless_upload.bucket
  output_bucket = aws_s3_bucket.serverless-transcode.bucket

  role         = aws_iam_role.transcoder.arn

}
#################
# Lambda Function Lab 1
#################
resource "aws_lambda_function" "serverless_lambda" {
  filename      = "./docker/lab1/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-transcode-video"
  role          = aws_iam_role.serverless_lambda.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab1/app/Lambda-Deployment.zip") ? "./docker/lab1/app/Lambda-Deployment.zip" : "./docker/lab1/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      ELASTIC_TRANSCODER_REGION = var.region
      ELASTIC_TRANSCODER_PIPELINE_ID = aws_elastictranscoder_pipeline.serverless.id
    }
  }
  depends_on = [docker_container.lambda_packager]
}
#################
# Lambda Trigger
#################
resource "aws_lambda_permission" "allow_serverless_upload" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.serverless_upload.arn
}

resource "aws_s3_bucket_notification" "serverless_upload" {
  bucket = aws_s3_bucket.serverless_upload.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.serverless_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_serverless_upload]
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
# Docker Provider to package node modules
#################
provider "docker" {}
provider "null" {}

resource "null_resource" "lambda_packager" {
  triggers = {
    cluster_instance_ids = filesha1("./docker/lambda_packager/Dockerfile")
  }
  provisioner "local-exec" {
    command = "docker build -t lambda_packager ./docker/lambda_packager/"
  }
}
locals {
  lambda_packages = [
    fileexists("./docker/lab1/app/Lambda-Deployment.zip") ? "" :  "./docker/lab1/app",
    fileexists("./docker/lab3/app/Lambda-Deployment.zip") ? "" :  "./docker/lab3/app",
    fileexists("./docker/lab3a/app/Lambda-Deployment.zip") ? "" :  "./docker/lab3a/app"
  ]
  compact_lambda_packages = compact(local.lambda_packages)
}

resource "docker_container" "lambda_packager" {
  count = length(local.compact_lambda_packages)
  image = "lambda_packager"
  name  = "lambda_packager${count.index}"
  mounts {
    type="bind"
    source=abspath(local.compact_lambda_packages[count.index])
    target="/app"
  }
  start = true
  depends_on = [null_resource.lambda_packager]
  provisioner "local-exec" {
    command =<<CMD
until [ -f ${abspath(local.compact_lambda_packages[count.index])}/Lambda-Deployment.zip ] ; do sleep 2; echo zipping; done
CMD
  }
}
#################
# IAM lambda basic role
#################
resource "aws_iam_role" "lambda_basic" {
  name = "${var.prefix}-basic-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execute" {
  role       = aws_iam_role.lambda_basic.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}
#################
# Lambda Function Lab 3
#################
resource "aws_lambda_function" "serverless_lambda_3" {
  filename      = "./docker/lab3/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-user-profile"
  role          = aws_iam_role.lambda_basic.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab3/app/Lambda-Deployment.zip") ? "./docker/lab3/app/Lambda-Deployment.zip" : "./docker/lab3/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      AUTH0_DOMAIN = var.AUTH0_DOMAIN
    }
  }
  depends_on = [docker_container.lambda_packager]
}


#################
# IAM lambda basic role 2
#################
resource "aws_iam_role" "lambda_basic_2" {
  name = "${var.prefix}-basic-role2"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execute_2" {
  role       = aws_iam_role.lambda_basic.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}
#################
# Authorizor
#################
resource "aws_iam_role" "authorizer" {
  name = "${var.prefix}-authorizer"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "authorizer" {
  name = "default"
  role = aws_iam_role.authorizer.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.serverless_lambda_3a.arn}"
    }
  ]
}
EOF
}

resource "aws_api_gateway_authorizer" "custom_auth" {
  name                   = "custom-auth"
  rest_api_id            = aws_api_gateway_rest_api.serverless_api.id
  authorizer_uri         = aws_lambda_function.serverless_lambda_3a.invoke_arn
  authorizer_credentials = aws_iam_role.authorizer.arn
}

resource "aws_lambda_function" "serverless_lambda_3a" {
  filename      = "./docker/lab3a/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-custom-authorizor"
  role          = aws_iam_role.lambda_basic.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab3a/app/Lambda-Deployment.zip") ? "./docker/lab3a/app/Lambda-Deployment.zip" : "./docker/lab3a/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      AUTH0_DOMAIN = var.AUTH0_DOMAIN
    }
  }
  depends_on = [docker_container.lambda_packager]
}
#################
# Lab 3b
#################
resource "local_file" "website_config_3" {
    content     =  templatefile("./docker/lab3b/app/js/config_template.js", { domain = var.AUTH0_DOMAIN, clientId = var.AUTH0_CLIENT_ID, apiBaseUrl = aws_api_gateway_deployment.deploy.invoke_url })
    filename = "./docker/lab3b/app/js/config.js"
}
