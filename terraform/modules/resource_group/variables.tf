variable "location" { type = string }
variable "environment" { type = string }
variable "product_identifier" { type = string }
variable "product_name" { type = string }
variable "services" {
  type = list(object({
    service_identifier = string
    github = object({
      org         = string
      repo        = string
      entity      = string
      entity_name = string
    })
  }))
  default = []
}
