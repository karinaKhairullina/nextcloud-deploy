variable "zone" {
  type        = string
  default     = "ru-central1-d"
}

variable "cloud_id" {
  type        = string
  description = "Cloud ID"
}

variable "folder_id" {
  type        = string
  description = "Folder ID"
}


variable "project_name" {
  type        = string
  default     = "nextcloud-project"
}

variable "key_file_path" {
  type        = string
  description = "Ключ сервисного аккаунта"
}

