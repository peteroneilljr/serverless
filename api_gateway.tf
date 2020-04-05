# -----------------------------------------------------------------------------
# Resources: API Gateway
# -----------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "serverless_api" {
  name = "${var.prefix}-rest-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
module "api_gateway_resource" {
  source  = "./modules/terraform-aws-api-gateway-resource"

  api = aws_api_gateway_rest_api.serverless_api.id
  root_resource = aws_api_gateway_rest_api.serverless_api.root_resource_id

  resource = "user-profile"
  # origin = "https://example.com"

  num_methods = 1
  methods = [
    {
      method = "GET"
      type = "AWS_PROXY", # Optionally override lambda integration type, defaults to "AWS_PROXY"
      invoke_arn = aws_lambda_function.serverless_lambda_3.invoke_arn
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
    #   invoke_arn = aws_lambda_function.serverless_lambda_3.invoke_arn
    # }
  ]
}


resource "aws_api_gateway_authorizer" "custom_auth" {
  name                   = "custom-auth"
  rest_api_id            = aws_api_gateway_rest_api.serverless_api.id
  authorizer_uri         = aws_lambda_function.serverless_lambda_3a.invoke_arn
  authorizer_credentials = aws_iam_role.authorizer.arn
}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [module.api_gateway_resource]

  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  stage_name  = "deploy"
}
