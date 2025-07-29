# -----------------------------------------------------------------------------
# iam.tf
#
# This file defines the specific service account and IAM permissions
# the function needs to do its job.
# -----------------------------------------------------------------------------

# NEW: Create a dedicated service account specifically for this function.
# resource "google_service_account" "function_sa" {
#   account_id   = "self-landing-to-raw-sa"
#   display_name = "SA for Landing to Raw Transformer Function"
#   project      = var.gcp_project_id
# }

# Grant the function's SA permissions to be invoked by Eventarc.
resource "google_project_iam_member" "eventarc_trigger_invoker" {
  project = var.gcp_project_id
  role    = "roles/run.invoker"
  # UPDATED: Use the locally created service account
  member  = "serviceAccount:${data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function}"
}

# FIXED: Grant the function's SA permissions to receive events from Eventarc.
resource "google_project_iam_member" "eventarc_event_receiver" {
  project = var.gcp_project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function}"

  depends_on = [google_project_service.apis]
}


# Grant the function's SA permissions to read from the landing bucket.
resource "google_storage_bucket_iam_member" "function_sa_can_read_from_landing_bucket" {
  bucket = data.terraform_remote_state.platform.outputs.landing_bucket_name
  role   = "roles/storage.objectViewer"
  # UPDATED: Use the locally created service account
  member = "serviceAccount:${data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function}"
}

# Grant the function's SA permissions to write to the new raw Parquet bucket.
resource "google_storage_bucket_iam_member" "function_sa_can_write_to_raw_bucket" {
  bucket = data.terraform_remote_state.platform.outputs.raw_bucket_name
  role   = "roles/storage.objectAdmin" # Needs full control to write/overwrite
  # UPDATED: Use the locally created service account
  member = "serviceAccount:${data.terraform_remote_state.platform.outputs.data_platform_service_account_email_transformer_function}"
}