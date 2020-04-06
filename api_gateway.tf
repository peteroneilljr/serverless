# -----------------------------------------------------------------------------
# Resources: API Gateway
# -----------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "serverless_api" {
  name = "${var.prefix}-acg-video-uploader"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [module.resource_s3_upload_link, module.resource_user_profile]

  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  stage_name  = "deploy"

  variables = {
    version = "0.11"
  }
}
#################
# Authorizer
#################
resource "aws_api_gateway_authorizer" "custom_auth" {
  name                   = local.custom_authorizer_name
  rest_api_id            = aws_api_gateway_rest_api.serverless_api.id
  authorizer_uri         = aws_lambda_function.custom_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.authorizer.arn
}
#################
# /user-profile
#################
module "resource_user_profile" {
  source  = "./modules/terraform-aws-api-gateway-resource"

  api = aws_api_gateway_rest_api.serverless_api.id
  root_resource = aws_api_gateway_rest_api.serverless_api.root_resource_id

  resource = local.user_profile_name

  num_methods = 1
  methods = [
    {
      method = "GET"
      type = "AWS_PROXY", # Optionally override lambda integration type, defaults to "AWS_PROXY"
      invoke_arn = aws_lambda_function.user_profile.invoke_arn
      auth = "CUSTOM"
      auth_id = aws_api_gateway_authorizer.custom_auth.id
      models = { "application/json" = "Empty" }
      request_param = { 
        "method.request.header.authorization" = false
        "method.request.querystring.accessToken" = false 
      }
    }
    # ,
    # {
    #   method = "DELETE"
    #   invoke_arn = aws_lambda_function.user_profile.invoke_arn
    # }
  ]
}
#################
# /s3-upload-link
#################
module "resource_s3_upload_link" {
  source  = "./modules/terraform-aws-api-gateway-resource"

  api = aws_api_gateway_rest_api.serverless_api.id
  root_resource = aws_api_gateway_rest_api.serverless_api.root_resource_id

  resource = local.s3_upload_link_name

  num_methods = 1
  methods = [
    {
      method = "GET"
      type = "AWS_PROXY", # Optionally override lambda integration type, defaults to "AWS_PROXY"
      invoke_arn = aws_lambda_function.s3_upload_link.invoke_arn
      auth = "CUSTOM"
      auth_id = aws_api_gateway_authorizer.custom_auth.id
      models = { "application/json" = "Empty" }
      request_param = { 
        "method.request.querystring.filename" = false 
        "method.request.querystring.filetype" = false 
        "method.request.header.authorization" = false
      }
    }
  ]
}