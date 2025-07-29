# -----------------------------------------------------------------------------
# main.tf
#
# This file defines the Cloud Function and its specific IAM bindings.
# -----------------------------------------------------------------------------

# locals {
#   # A list of all APIs required by the resources in this function repository.
#   required_apis = [
#     "iam.googleapis.com",
#     "cloudfunctions.googleapis.com",
#     "cloudbuild.googleapis.com",
#     "eventarc.googleapis.com",
#     "run.googleapis.com",
#     "storage.googleapis.com",
#     "artifactregistry.googleapis.com",
#   ]
# }

# resource "google_project_service" "apis" {
#   project                    = var.gcp_project_id
#   for_each                   = toset(local.required_apis)
#   service                    = each.value
#   disable_on_destroy         = false # Keep APIs enabled even if Terraform destroys resources
#   disable_dependent_services = true
# }

# Define the Cloud Function resource.
resource "google_cloudfunctions2_function" "landing_to_raw_loader" {
  name     = "self-landing-to-raw-loader-function"
  location = var.gcp_region

  build_config {
    runtime     = "python311"
    entry_point = "transform_csv_to_parquet"
    source {
      repo_source {
        project_id  = var.gcp_project_id
        repo_name   = var.function_repo_name
        branch_name = var.function_repo_branch
        dir         = "src/load_landing_to_raw/"

      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "512Mi"
    timeout_seconds       = 300
    # UPDATED: Use the locally created service account
    service_account_email = data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function
    # The function now needs the name of the raw bucket
    environment_variables = {
      PROJECT_ID      = var.gcp_project_id
      RAW_BUCKET_NAME = data.terraform_remote_state.platform.outputs.raw_bucket_name
    }
  }

  event_trigger {
    trigger_region        = var.gcp_region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_RETRY"
    # UPDATED: Use the locally created service account
    service_account_email = data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function
    event_filters {
      attribute = "bucket"
      # Get the landing bucket name from the platform's remote state
      value     = data.terraform_remote_state.platform.outputs.landing_bucket_name
    }
  }

  depends_on = [
    # Depend on the IAM bindings to ensure they are created first
    google_project_iam_member.eventarc_trigger_invoker,
    google_storage_bucket_iam_member.function_sa_can_write_to_raw_bucket,
    google_storage_bucket_iam_member.function_sa_can_read_from_landing_bucket,
  ]
}