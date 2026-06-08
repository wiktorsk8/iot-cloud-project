variable "location" {
  type    = string
  default = "switzerlandnorth"
}

variable "rg_name" {
  type    = string
  default = "rg-iot-projekt"
}

variable "acr_name" {
  type = string
}

variable "app_name" {
  type = string
}

variable "plan_name" {
  type    = string
  default = "plan-iot-projekt"
}

variable "sql_server_name" {
  type = string
}

variable "sql_db_name" {
  type    = string
  default = "iotdb"
}

variable "sql_admin_login" {
  type    = string
  default = "sqladmin"
}

variable "image_name" {
  type    = string
  default = "iot-app"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "container_port" {
  type    = string
  default = "8000"
}

variable "my_ip" {
  type    = string
  default = ""
}