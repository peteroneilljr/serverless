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
data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "allow_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.serverless_lambda_3.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.serverless_api.id}/*/${module.api_gateway_resource.http_method[0]}${module.api_gateway_resource.path}"
}

resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [module.api_gateway_resource]

  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  stage_name  = "deploy"
}
