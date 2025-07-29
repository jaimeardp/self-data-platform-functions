# -----------------------------------------------------------------------------
# apis.tf
#
# NEW FILE: This file enables all the necessary APIs for this function.
# -----------------------------------------------------------------------------

locals {
  # A list of all APIs required by the resources in this function repository.
  required_apis = [
    "iam.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  project                    = var.gcp_project_id
  for_each                   = toset(local.required_apis)
  service                    = each.value
  disable_on_destroy         = false # Keep APIs enabled even if Terraform destroys resources
  disable_dependent_services = true
}