#################
# Assume service
#################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
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
#################
# IAM lambda transcoder role
#################
resource "aws_iam_role" "serverless_lambda" {
  name = "${var.prefix}-lambda-transcoder-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
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
# IAM lambda basic role user profile
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
# IAM lambda basic role 2 custom authorizer
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
# Custom Authorizor execution role
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
