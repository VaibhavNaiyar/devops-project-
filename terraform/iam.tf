# Instance roles: no access keys are ever stored on the servers.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------- App servers: pull images from ECR, read/write the DynamoDB table ----------
resource "aws_iam_role" "app" {
  name               = "${var.project}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "app_ecr_read" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy_document" "app_dynamodb" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Scan", "dynamodb:Query"]
    resources = [aws_dynamodb_table.requests.arn]
  }
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name   = "dynamodb-requests-table"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_dynamodb.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-app-profile"
  role = aws_iam_role.app.name
}

# ---------- Jenkins: push to ECR, find app servers, drain/register ALB targets, read/write release params ----------
resource "aws_iam_role" "jenkins" {
  name               = "${var.project}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "jenkins" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:DescribeImages",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
  statement {
    sid       = "DiscoverInstances"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags", "elasticloadbalancing:Describe*"]
    resources = ["*"]
  }
  statement {
    sid       = "RollingDeployTargets"
    actions   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
    resources = [aws_lb_target_group.app.arn]
  }
  statement {
    sid       = "ReleaseParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "jenkins" {
  name   = "jenkins-cicd"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}
