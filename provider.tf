# -----------------------------------------------------------------------------
# provider.tf
#
# Defines the Google Cloud provider configuration.
# -----------------------------------------------------------------------------
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}