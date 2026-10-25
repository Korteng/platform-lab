variable "env_name" {
  description = "Environment name, used in resource names"
  type        = string
}

variable "host_port" {
  description = "Host port for the web container"
  type        = number
}

variable "nginx_image" {
  description = "nginx image tag"
  type        = string
  default     = "nginx:1.27-alpine"
}
