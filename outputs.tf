# -----------------------------------------------------------------------------
# outputs.tf
#
# Defines outputs for this function's deployment.
# -----------------------------------------------------------------------------

output "cloud_function_name" {
  description = "The name of the event-driven Cloud Function."
  value       = google_cloudfunctions2_function.landing_to_raw_loader.name
}

output "cloud_function_uri" {
  description = "The URI of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.landing_to_raw_loader.service_config[0].uri
}

output "function_service_account_email" {
  description = "The email of the dedicated service account created for this function."
  value       = google_service_account.function_sa.email
}
