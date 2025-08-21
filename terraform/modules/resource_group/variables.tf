variable "location" { type = string }
variable "environment" { type = string }
variable "product_identifier" { type = string }
variable "product_name" { type = string }
variable "services" {
  # Each service entry provisions a deployment state container and GitHub OIDC credential
  type = list(object({
    service_identifier = string
    github = object({
      repository = string
    })
  }))
  default = []
}
