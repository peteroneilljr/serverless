#################
# Docker uses a Node container to run npm install and create ZIP for lambda upload
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
until [ -f ${abspath(local.compact_lambda_packages[count.index])}/Lambda-Deployment.zip ] ; do sleep 2; echo packaging_lambda_code; done
CMD
  }
}

#################
# Lambda Function Lab 1
#################
resource "aws_lambda_permission" "allow_serverless_upload" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.serverless_upload.arn
}

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
# Lambda Function Lab 3
#################
resource "aws_lambda_permission" "allow_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless_lambda_3.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.serverless_api.execution_arn}/*/*/*"
}

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
# Customer Authorizer
#################
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