# -----------------------------------------------------------------------------
# main.tf
#
# This file defines the Cloud Function and its specific IAM bindings.
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

# 1. Create a zip archive of the function's source code from the local 'source' directory.
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/${var.function_source_dir}"
  output_path = "/tmp/function_source.zip"
}

# 2. Upload the zipped source code to the GCS bucket.
resource "google_storage_bucket_object" "function_source_object" {
  name   = "source.zip"
  bucket = data.terraform_remote_state.platform.outputs.data_plataform_bucket_name_for_function_source
  source = data.archive_file.function_source.output_path
}


# Define the Cloud Function resource.
resource "google_cloudfunctions2_function" "landing_to_raw_loader" {
  name     = "self-landing-to-raw-loader-function"
  location = var.gcp_region

  build_config {
    runtime     = "python311"
    entry_point = "transform_csv_to_parquet"
    source {
      storage_source {
        bucket = data.terraform_remote_state.platform.outputs.data_plataform_bucket_name_for_function_source
        object = google_storage_bucket_object.function_source_object.name
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
    google_project_iam_member.eventarc_event_receiver, # <-- ADDED DEPENDENCY
    google_storage_bucket_iam_member.function_sa_can_write_to_raw_bucket,
    google_storage_bucket_iam_member.function_sa_can_read_from_landing_bucket,
  ]
}