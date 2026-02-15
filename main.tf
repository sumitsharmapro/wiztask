# NETWORK
data "google_compute_network" "main" {
  name = "wiz-vpc"
}

data "google_compute_subnetwork" "public" {
  name   = "public-subnet"
  region = "us-central1"
}

data "google_compute_subnetwork" "private" {
  name   = "private-subnet"
  region = "us-central1"
}

# HELPERS
resource "random_id" "id" {
  byte_length = 4
}

# outdated mongodb
resource "google_compute_instance" "mongodb_vm" {
  name         = "mongodb-outdated-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10" # old os
    }
  }

  network_interface {
    network    = data.google_compute_network.main.id
    subnetwork = data.google_compute_subnetwork.public.id
    access_config {} # public IP
  }

  service_account {
    email  = "github-deployer@clgcporg10-170.iam.gserviceaccount.com"
    scopes = ["cloud-platform"] # God Mode permissions
  }

  metadata_startup_script = <<-EOF
    sudo apt-get update
    sudo apt-get install -y gnupg wget
    
    # old db version
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo systemctl start mongod

    # open bucket
    echo "mongodump --out /tmp/backup && gsutil cp -r /tmp/backup gs://${google_storage_bucket.backup_bucket.name}/" > /usr/local/bin/backup.sh
    chmod +x /usr/local/bin/backup.sh
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/backup.sh") | crontab -
  EOF
}

# open bucket
resource "google_storage_bucket" "backup_bucket" {
  name          = "wiz-db-backups-${random_id.id.hex}"
  location      = "US"
  force_destroy = true
  public_access_prevention = "inherited"
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers" # open bucket
}

# open ssh
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-public"
  network = data.google_compute_network.main.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # open fw
}


resource "google_container_cluster" "primary" {
  name     = "wiz-cluster"
  location = "us-central1-a"
  network    = data.google_compute_network.main.name
  subnetwork = data.google_compute_subnetwork.private.name 
  
  initial_node_count = 1
  deletion_protection = false

  node_config {
    service_account = "github-deployer@clgcporg10-170.iam.gserviceaccount.com"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
