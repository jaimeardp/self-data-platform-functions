# -----------------------------------------------------------------------------
# data.tf
#
# This file defines data sources to read information from other places,
# including the state file of our platform infrastructure.
# -----------------------------------------------------------------------------
data "terraform_remote_state" "platform" {
  backend = "gcs"
  config = {
    bucket = "self-tfstate-bkt" # Using the same state bucket
    prefix = "platform/infra"
  }
}