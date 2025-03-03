locals {
  email_to_validate = (
    var.generate_subspace_config == true
    ? var.admin_user_email
    : ""
  )

}

module "validate_email" {
  source  = "rhythmictech/errorcheck/terraform"
  version = "1.0.0"

  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  assert = (
    var.generate_subspace_config == false ||
    length(regexall("(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$)", local.email_to_validate)) > 0
  )
  error_message = "The email provider for the admin account is invalid: ${local.email_to_validate}"
}

resource "random_password" "this" {
  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  length      = 20
  special     = true
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  min_upper   = 2
}

resource "tls_private_key" "saml_cert" {
  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "saml_cert" {
  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  private_key_pem = tls_private_key.saml_cert[0].private_key_pem

  subject {
    common_name  = var.vpn_endpoint_url
    organization = "Subspace"
  }

  validity_period_hours = 5 * 365 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "random_password" "hash_key" {
  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  length  = 32
  special = false
  upper   = true
  lower   = true
  number  = true
}

resource "random_password" "block_key" {
  count = (
    var.generate_subspace_config
    ? 1
    : 0
  )
  length  = 32
  special = false
  upper   = true
  lower   = true
  number  = true
}

locals {
  subspace_config = (
    var.generate_subspace_config
    ? {
      info = {
        email     = var.admin_user_email
        password  = base64encode(bcrypt(random_password.this[0].result, 10))
        secret    = ""
        totp_key  = ""
        configure = true
        domain    = ""
        hash_key  = random_password.hash_key[0].result
        block_key = random_password.block_key[0].result
        saml = {
          idp_metadata = ""
          private_key  = base64encode(tls_private_key.saml_cert[0].private_key_pem)
          certificate  = base64encode(tls_self_signed_cert.saml_cert[0].cert_pem)
        }
        mail = {
          from     = ""
          server   = ""
          port     = 0
          username = ""
          password = ""
        }
      }
      profiles = null
      users    = null
      modified = "0001-01-01T00:00:00Z"
    }
    : null
  )
}
