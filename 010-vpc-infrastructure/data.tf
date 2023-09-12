# Pull in the zones in the region
data "ibm_is_zones" "regional" {
  region = var.region
}