resource "google_project_iam_audit_config" "project_audit" {
  project = "clgcporg59-p001"
  service = "allServices"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

resource "google_service_account" "github_deployer" {
  project      = "clgcporg59-p001"
  account_id   = "github-deployer"
  display_name = "GitHub Actions Service Account"
}

resource "google_compute_network" "main" {
  name                    = "wiz-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "private" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.main.id
}

resource "google_compute_router" "router" {
  name    = "wiz-router"
  region  = "us-central1"
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "wiz-nat"
  router                             = google_compute_router.router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "random_id" "id" {
  byte_length = 4
}

resource "google_artifact_registry_repository" "wiz_app_repo" {
  location      = "us-central1"
  repository_id = "wiz-app-repo"
  format        = "DOCKER"
}

resource "google_compute_instance" "mongodb_vm" {
  name         = "mongodb-outdated-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.public.id
    access_config {}
  }

  service_account {
    email  = google_service_account.github_deployer.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y gnupg wget
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    
    sudo systemctl restart mongod
    sudo systemctl enable mongod

    echo "mongodump --out /tmp/backup && gsutil cp -r /tmp/backup gs://${google_storage_bucket.backup_bucket.name}/" > /usr/local/bin/backup.sh
    chmod +x /usr/local/bin/backup.sh
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/backup.sh") | crontab -
  EOF

  allow_stopping_for_update = true
}

resource "google_storage_bucket" "backup_bucket" {
  name                        = "wiz-db-backups-${random_id.id.hex}"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "inherited"
}

resource "google_storage_bucket" "secure_assets" {
  name                        = "wiz-secure-assets-${random_id.id.hex}"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "enforced" 
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-public"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_mongodb_internal" {
  name    = "allow-mongodb-internal"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }
  source_ranges = ["10.0.0.0/8"] 
}

resource "google_container_cluster" "primary" {
  name       = "wiz-cluster"
  location   = "us-central1-a"
  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.private.name 
  
  initial_node_count  = 1
  deletion_protection = false

  node_config {
    service_account = google_service_account.github_deployer.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = "clgcporg59-p001"
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = "clgcporg59-p001"
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"
  
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  
  attribute_condition = "assertion.repository == 'sumitsharmapro/wiztask'"
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/sumitsharmapro/wiztask"
  ]
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = "clgcporg59-p001"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_project_iam_member" "gke_developer" {
  project = "clgcporg59-p001"
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}
