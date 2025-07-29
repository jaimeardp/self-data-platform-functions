# -----------------------------------------------------------------------------
# variables.tf
#
# This file declares all the variables for the function's configuration.
# -----------------------------------------------------------------------------

variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID where the resources will be created."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for the resources."
  default     = "us-central1"
}

variable "function_repo_name" {
  type        = string
  description = "The name of the Cloud Source Repository for the function code."
  default     = "self-data-platform-functions"
}

variable "function_repo_branch" {
  type        = string
  description = "The branch name to deploy the function from."
  default     = "main"
}

variable "github_repository_name" {
  type        = string
  description = "The name of the GitHub repository for the function code."
  default     = "self-data-platform-functions"
}
