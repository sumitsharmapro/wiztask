terraform {
  backend "gcs" {
    bucket = "clgcporg53-p001-tfstate"
    prefix = "terraform/state"
  }
}
