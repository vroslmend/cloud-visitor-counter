output "api_base_url" {
  description = "Base URL of the HTTP API. GET {url}/counts, POST {url}/counts/{id}/hit"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "dynamodb_table" {
  description = "Name of the counter table"
  value       = aws_dynamodb_table.counter.name
}

output "ci_role_arn" {
  description = "ARN GitHub Actions assumes via OIDC — set as the AWS_ROLE_ARN repo variable"
  value       = aws_iam_role.ci.arn
}
