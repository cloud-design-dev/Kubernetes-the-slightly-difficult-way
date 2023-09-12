variable "ibmcloud_api_key" {
  description = "IBM Cloud API key to create resources"
  type        = string
}

variable "region" {
  description = "Region where to find and create resources. Run `ibmcloud is regions` to see available regions"
  type        = string
}

variable "basename" {
  description = "Prefix for all resources created by the template. Will also be added as a tag to all resources in the form of `project:basename`"
  type        = string
}

variable "owner" {
  description = "Owner of the resources. Will be added as a tag in the form of `owner:owner`"
  type        = string
}

variable "allow_ip_spoofing" {
  description = "Allow IP Spoofing"
  type        = bool
  default     = true
}

variable "existing_ssh_key" {
  description = "Existing SSH key name"
  type        = string
}

variable "instance_profile" {
  description = "The profile to use for the instance"
  type        = string
  default     = "bx2-4x16"
}

variable "image_name" {
  description = "The name of an existing OS image to use. You can list available images with the command 'ibmcloud is images'."
  type        = string
  default     = "ibm-ubuntu-22-04-2-minimal-amd64-1"
}

variable "metadata_service_enabled" {
  description = "Enable the metadata service on the bastion instance."
  type        = bool
  default     = true
}
