terraform {
  required_version = ">= 1.5.0"
}

provider "google" {
  project = "clgcporg10-170"
  region  = "us-central1"
}


# 2. Network - Isolated and Private
resource "google_compute_network" "vpc" {
  name                    = "wiz-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "wiz-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # Crucial for private GKE nodes
}

# 3. Artifact Registry - For Docker images
resource "google_artifact_registry_repository" "repo" {
  location      = "us-central1"
  repository_id = "wiz-app-repo"
  format        = "DOCKER"
}

# 4. GKE Identity - Zero Trust (Least Privilege)
resource "google_service_account" "gke_nodes" {
  account_id   = "wiz-gke-nodes"
  display_name = "GKE Nodes Service Account"
}

resource "google_project_iam_member" "gke_registry_reader" {
  project = "clgcporg10-170"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# 5. GKE Cluster - Fully Private for Security
resource "google_container_cluster" "primary" {
  name     = "wiz-cluster"
  location = "us-central1-a"
  network  = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id
  
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep master public for easy kubectl access
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}

resource "google_container_node_pool" "nodes" {
  name       = "wiz-pool"
  cluster    = google_container_cluster.primary.name
  location   = "us-central1-a"
  node_count = 1

  node_config {
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    machine_type    = "e2-medium"
  }
}
