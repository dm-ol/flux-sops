variable "GOOGLE_PROJECT" {
  type        = string
  default     = "learning-405310"
  description = "GCP project name"
}

variable "GOOGLE_REGION" {
  type        = string
  default     = "us-central1-b"
  description = "GCP region to use"
}

variable "GKE_MACHINE_TYPE" {
  type        = string
  default     = "e2-standard-2"
  description = "Machine type"
}

variable "GKE_CLUSTER_NAME" {
  type        = string
  default     = "gke-flux"
  description = "GKE cluster name"
}

variable "GKE_NUM_NODES" {
  type        = number
  default     = 2
  description = "GKE nodes number"
}

variable "GITHUB_OWNER" {
  type        = string
  default     = "dm-ol"
  description = "The GitHub owner"
}

variable "GITHUB_TOKEN" {
  type        = string
  description = "GitHub personal access token"
}

variable "FLUX_GITHUB_REPO" {
  type        = string
  default     = "gke-flux"
  description = "Flux GitHub repository"
}

variable "FLUX_GITHUB_TARGET_PATH" {
  type        = string
  default     = "clusters"
  description = "Flux manifests subdirectory"
}