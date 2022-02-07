variable "db_allocated_storage" {
  type              = number
  description       = "The allocated storage for database"
}

variable "db_instance_class" {
  type              = string
  description       = "The instance class for the database"
}

variable "db_name" {
  type              = string
  description       = "The name for the database"
}

variable "db_username" {
  type              = string
  description       = "The username for the database"
}

variable "db_password" {
  type              = string
  description       = "The password for the database"
}
