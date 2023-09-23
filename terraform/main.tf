data "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name
}

locals {
  account_id  = regex("^arn:aws:eks:[a-z0-9-]+:(\\d+)", "${data.aws_eks_cluster.eks_cluster.arn}")[0]
  cluster_oidc = trimprefix("${data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer}", "https://")
}
 
# KMS
resource "aws_kms_key" "vault_unseal_tf" {
  description = "Vault unseal - Terraform"
}

resource "aws_kms_alias" "vault_unseal_tf_key_alias" {
  name          = "alias/vault_unseal_tf"
  target_key_id = aws_kms_key.vault_unseal_tf.key_id
}

# Role and policy.
resource "aws_iam_role" "vault_kms_unseal_role_tf" {
  name = "vault_kms_unseal_role_tf"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      },
      {
        "Effect": "Allow",
        "Principal": {
            "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${local.cluster_oidc}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
              "${local.cluster_oidc}:sub": "system:serviceaccount:default:${var.vault_service_account_name}",
              "${local.cluster_oidc}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "vault_kms_unseal_policy_tf" {
  name = "vault_kms_unseal_policy_tf"
  role = aws_iam_role.vault_kms_unseal_role_tf.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "VaultKMSUnseal",
        "Effect": "Allow",
        "Action": [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:DescribeKey",
            "ec2:DescribeInstances"
        ],
        "Resource": [
            "${aws_kms_key.vault_unseal_tf.arn}"
        ]
      }
    ]
  }
  EOF
}

locals {
  rendered_content = templatefile(
    "${path.module}/override-values-auto.yml.tftpl",
    {
      vault_auto_unseal_role_arn = aws_iam_role.vault_kms_unseal_role_tf.arn,
      vault_auto_unseal_kms_key_id = aws_kms_key.vault_unseal_tf.key_id
    }
  )
}

resource "local_file" "helm_overrides" {
  filename = "${path.module}/override-values-auto.yml"
  content  = local.rendered_content
}
