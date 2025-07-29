# -----------------------------------------------------------------------------
# backend.tf
#
# Defines the remote backend for the PLATFORM state.
# -----------------------------------------------------------------------------
terraform {
  backend "gcs" {
    bucket = "self-tfstate-bkt" # Best-practice name for the state bucket
    prefix = "platform/gcs-transformer"
  }
}