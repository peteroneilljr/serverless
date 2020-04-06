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
    fileexists("./docker/lab3a/app/Lambda-Deployment.zip") ? "" :  "./docker/lab3a/app",
    fileexists("./docker/lab4/app/Lambda-Deployment.zip") ? "" :  "./docker/lab4/app",
    fileexists("./docker/lab5a/app/Lambda-Deployment.zip") ? "" :  "./docker/lab5a/app",
    fileexists("./docker/lab5b/app/Lambda-Deployment.zip") ? "" :  "./docker/lab5b/app",
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
# Lambda Function Lab 1 & 5 
#################
resource "aws_s3_bucket_notification" "serverless_upload" {
  bucket = aws_s3_bucket.serverless_upload.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcode_video.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.transcode_video]
}

resource "aws_lambda_permission" "transcode_video" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcode_video.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.serverless_upload.arn
}

resource "aws_lambda_function" "transcode_video" {
  # filename      = "./docker/lab1/app/Lambda-Deployment.zip"
  filename      = "./docker/lab5a/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-transcode-video"
  role          = aws_iam_role.transcode_video.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab5a/app/Lambda-Deployment.zip") ? "./docker/lab5a/app/Lambda-Deployment.zip" : "./docker/lab5a/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      ELASTIC_TRANSCODER_REGION = var.region
      ELASTIC_TRANSCODER_PIPELINE_ID = aws_elastictranscoder_pipeline.serverless.id
      DATABASE_URL = var.FIREBASE_URL
    }
  }
  depends_on = [docker_container.lambda_packager]
}

#################
# Lambda Function Lab 3
#################
locals {
  user_profile_name = "user-profile"
}
resource "aws_lambda_permission" "user_profile" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_profile.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.serverless_api.execution_arn}/*/GET/${local.user_profile_name}"
}
resource "aws_lambda_function" "user_profile" {
  filename      = "./docker/lab3/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-${local.user_profile_name}"
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
locals {
  custom_authorizer_name = "custom-authorizer"
}

resource "aws_lambda_function" "custom_authorizer" {
  filename      = "./docker/lab3a/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-${local.custom_authorizer_name}"
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
# Lambda Function Lab 4
#################
locals {
  s3_upload_link_name = "s3-upload-link"
}
resource "aws_lambda_permission" "s3_upload_link" {
  statement_id  = "AllowExecutionFromAPIGatewaySignedURL"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_upload_link.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.serverless_api.execution_arn}/*/GET/${local.s3_upload_link_name}"
}

resource "aws_lambda_function" "s3_upload_link" {
  filename      = "./docker/lab4/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-${local.s3_upload_link_name}"
  role          = aws_iam_role.s3_upload_link.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab4/app/Lambda-Deployment.zip") ? "./docker/lab4/app/Lambda-Deployment.zip" : "./docker/lab4/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      UPLOAD_BUCKET_NAME = aws_s3_bucket.serverless_upload.bucket
    }
  }
  depends_on = [docker_container.lambda_packager]
}
#################
# Lab 5 push transcoder to firebase
#################
resource "aws_s3_bucket_notification" "push_to_firebase" {
  bucket = aws_s3_bucket.serverless_transcode.bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.push_to_firebase.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.push_to_firebase]
}

resource "aws_lambda_permission" "push_to_firebase" {
  statement_id  = "AllowExecutionFromS3TranscoderBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push_to_firebase.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.serverless_transcode.arn
}

resource "aws_lambda_function" "push_to_firebase" {
  filename      = "./docker/lab5b/app/Lambda-Deployment.zip"
  function_name = "${var.prefix}-push-to-firebase"
  role          = aws_iam_role.lambda_basic.arn
  handler       = "index.handler"

  # Zip is created after first run, so it will be uploaded twice.
  source_code_hash = filebase64sha256( fileexists("./docker/lab5b/app/Lambda-Deployment.zip") ? "./docker/lab5b/app/Lambda-Deployment.zip" : "./docker/lab3/app/index.js" )

  runtime = "nodejs12.x"
  timeout = 30

  environment {
    variables = {
      DATABASE_URL = var.FIREBASE_URL
      S3_TRANSCODED_BUCKET_URL = "https://${aws_s3_bucket.serverless_transcode.bucket}.s3.amazonaws.com" 
    }
  }
  depends_on = [docker_container.lambda_packager]
}
