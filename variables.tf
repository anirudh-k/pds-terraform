variable "project" {}

variable "region" {
  type        = string
  description = "GCP Region"
  default     = "us-east5"
}

variable "zone" {
  type        = string
  description = "GCP Zone"
  default     = "us-east5-a"
}