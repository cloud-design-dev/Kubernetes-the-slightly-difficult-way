variable "ibmcloud_api_key" {
  description = "IBM Cloud API key to create resources"
  type        = string
}

variable "region" {
  description = "Region where to find and create resources. Run `ibmcloud is regions` to see available regions"
  type        = string
  default     = "us-south"
}

variable "basename" {
  description = "Prefix for all resources created by the template. Will also be added as a tag to all resources in the form of `project:basename`"
  type        = string
  default     = "client-vpn"
}

variable "existing_resource_group" {
  description = "Existing resource group name where to create resources. If not set, a new resource group will be created."
  type        = string
}

variable "tags" {
  description = "Tags to add to all resources"
  type        = list(string)
  default     = ["terraform", "client-vpn"]
}


variable "owner" {
  description = "Owner of the resources. Will be added as a tag in the form of `owner:owner`"
  type        = string
}

variable "classic_access" {
  description = "Allow classic access to the VPC."
  type        = bool
  default     = false
}

variable "default_address_prefix" {
  description = "The address prefix to use for the VPC. Default is set to auto."
  type        = string
  default     = "auto"
}

variable "number_of_addresses" {
  description = "Number of IPs to assign for each subnet."
  type        = number
  default     = 128
}

variable "bastion_rules" {
  description = "A list of security group rules to be added to the bastion security"
  type = list(
    object({
      name      = string
      direction = string
      remote    = string
      tcp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      udp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      icmp = optional(
        object({
          type = optional(number)
          code = optional(number)
        })
      )
    })
  )
  default = [
    {
      name       = "inbound-ssh"
      direction  = "inbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      tcp = {
        port_min = 22
        port_max = 22
      }
    },
    {
      name       = "inbound-icmp"
      direction  = "inbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      icmp = {
        code = 0
        type = 8
      }
    },
    {
      name       = "dns-outbound"
      direction  = "outbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      udp = {
        port_min = 53
        port_max = 53
      }
    },
    {
      name       = "services-outbound"
      direction  = "outbound"
      remote     = "161.26.0.0/16"
      ip_version = "ipv4"
    },
    {
      name       = "all-outbound"
      direction  = "outbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
    }
  ]
}

variable "cluster_rules" {
  description = "A list of security group rules to be added to the bastion security"
  type = list(
    object({
      name      = string
      direction = string
      remote    = string
      tcp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      udp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      icmp = optional(
        object({
          type = optional(number)
          code = optional(number)
        })
      )
    })
  )
  default = [
    {
      name       = "inbound-api"
      direction  = "inbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      tcp = {
        port_min = 6443
        port_max = 6443
      }
    },
    {
      name       = "inbound-icmp"
      direction  = "inbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      icmp = {
        code = 0
        type = 8
      }
    },
    {
      name       = "dns-outbound"
      direction  = "outbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      udp = {
        port_min = 53
        port_max = 53
      }
    },
    {
      name       = "nodeport-inbound"
      direction  = "inbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
      tcp = {
        port_min = 30000
        port_max = 32767
      }
    },
    {
      name       = "services-outbound"
      direction  = "outbound"
      remote     = "161.26.0.0/16"
      ip_version = "ipv4"
    },
    {
      name       = "all-outbound"
      direction  = "outbound"
      remote     = "0.0.0.0/0"
      ip_version = "ipv4"
    }
  ]
}