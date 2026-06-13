# ---------------------------------------------------------------------------
# CI/CD auth — GitHub Actions assumes an IAM role via OpenID Connect.
# No access keys are ever stored in GitHub: each workflow run swaps a
# short-lived GitHub OIDC token for temporary AWS credentials.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# The trust anchor: AWS learns to trust tokens minted by GitHub Actions.
# (Only one provider per URL is allowed per account.)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Who may assume the CI role: only this repo, and only from a push to main
# or a pull request — not arbitrary branches or other repositories.
data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "${var.project}-ci-role"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json
}

# What CI may do: enough to plan/apply this stack and nothing else. Scoped
# per service, and to this project's resources where the service allows it.
data "aws_iam_policy_document" "ci_policy" {
  # Terraform remote state + the S3-native state lock.
  statement {
    sid       = "StateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::portfolio-counter-tfstate-aps1"]
  }
  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::portfolio-counter-tfstate-aps1/*"]
  }

  # The counter table.
  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:*"]
    resources = [aws_dynamodb_table.counter.arn]
  }

  # The function.
  statement {
    sid       = "Lambda"
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.project}"]
  }

  # The HTTP API and its children.
  statement {
    sid       = "ApiGateway"
    actions   = ["apigateway:*"]
    resources = ["arn:aws:apigateway:${var.region}::/*"]
  }

  # The function's log group. DescribeLogGroups has no resource-level scope.
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}:*",
    ]
  }
  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # The IAM the stack manages: the two project roles and the OIDC provider.
  statement {
    sid = "ProjectRoles"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviderTags",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  # Lambda needs its execution role passed to it at create/update time.
  statement {
    sid       = "PassLambdaRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-lambda-role"]
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "${var.project}-ci-policy"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci_policy.json
}
