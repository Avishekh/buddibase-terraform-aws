variable "KEYNAME" {
  type    = string
  default = "budibase"
}

variable "REGION" {
  type    = string
  default = "us-west-2"
}
variable "AZ" {
  type    = string
  default = "us-west-2a"
}
variable "AMI" {
  type    = string
  default = "ami-0518bb0e75d3619ca"
}
variable "INSTANCE_TYPE" {
  type    = string
  default = "t2.micro"
}
variable "IPADDRESS" {
  type    = string
  default = "34.208.21.94"
}

variable "ELASTICIPALLOC" {
  type    = string
  default = "eipalloc-047ceb23097c2a6ed"
}

variable "JWTSECRET" {
  type    = string
  default = "testsecret"
}
variable "ENV" {
  type    = string
  default = "PRODUCTION"
}

