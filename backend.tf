terraform {
  backend "gcs" {
    bucket = "clgcporg10-170-tfstate"
    prefix = "terraform/state"
  }
}
