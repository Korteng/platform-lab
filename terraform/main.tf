module "dev" {
  source    = "./modules/web"
  env_name  = "dev"
  host_port = 8091
}

module "stage" {
  source    = "./modules/web"
  env_name  = "stage"
  host_port = 8092
}
