resource "docker_network" "lab" {
  name = "tf-${var.env_name}"
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "tf-web-${var.env_name}"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.lab.name
  }

  ports {
    internal = 80
    external = var.host_port
  }

  memory      = 64
  memory_swap = 128
}
