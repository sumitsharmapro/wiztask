# 1. Outdated MongoDB VM
resource "google_compute_instance" "mongodb_vm" {
  name         = "mongodb-outdated-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  # Outdated Linux
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.public.id # Using public subnet
    access_config {} # Gives it a Public IP for SSH requirement
  }

  # Overly permissive Service Account
  service_account {
    email  = "github-deployer@clgcporg10-170.iam.gserviceaccount.com"
    scopes = ["cloud-platform"] # Full access to all APIs
  }

  # Startup script to install outdated MongoDB 4.4
  metadata_startup_script = <<-EOF
    sudo apt-get update
    sudo apt-get install -y gnupg wget
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo systemctl start mongod
  EOF
}

# 2. Publicly Readable Backup Bucket 
resource "google_storage_bucket" "backup_bucket" {
  name          = "wiz-db-backups-${random_id.id.hex}"
  location      = "US"
  force_destroy = true
  public_access_prevention = "inherited"
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers" # Publicly readable
}

# 3. Public SSH Firewall Rule
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-public"
  network = google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Exposed to internet
}
