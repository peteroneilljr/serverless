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
resource "aws_iam_role" "transcode_video" {
  name = "${var.prefix}-video-transcoder-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
}
resource "aws_iam_role_policy_attachment" "lambda_execute" {
  role       = aws_iam_role.transcode_video.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}
resource "aws_iam_role_policy_attachment" "elastic_jobs_submitter" {
  role       = aws_iam_role.transcode_video.name
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
# Lab 1 User profile basic execution role
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
# Lab 3 Custom Authorizer basic execution role
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
# Lab 3 Custom Authorizer execution role
#################
resource "aws_iam_role" "authorizer" {
  name = "${var.prefix}-authorizer"
  path = "/"
  
  force_detach_policies = true

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
      "Resource": [
        "${aws_lambda_function.custom_authorizer.arn}",
        "${aws_lambda_function.s3_upload_link.arn}"
      ]
    }
  ]
}
EOF
}
#################
# Lab 4 Signed URL execution role
#################
resource "aws_iam_role" "s3_upload_link" {
  name = "${var.prefix}-signed-url"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json

  force_detach_policies = true
}
resource "aws_iam_role_policy_attachment" "s3_upload_link" {
  role       = aws_iam_role.s3_upload_link.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
}
resource "aws_iam_role_policy" "s3_upload_link" {
  name = "default"
  role = aws_iam_role.s3_upload_link.id

  policy = <<POLICY
{
  "Id": "Policy1586145854688",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1586145679558",
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.serverless_upload.arn}/*"
    }
  ]
}
POLICY
}