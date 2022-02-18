  provider "google" {
  credentials = file("searce-msp-gcp-6bcc0aec066a.json")
  project = "searce-msp-gcp"
  region  = "asia-south1"
  zone    = "asia-south1-a"
}
// Cloud Run Example



 // 1. Creation of cloud run service
resource "google_cloud_run_service" "run" {
  
  for_each = var.service-image
  name     = each.key
  location = "asia-south1"

  template {
    spec {
        service_account_name = "cloud-run-az@searce-msp-gcp.iam.gserviceaccount.com" 
      containers {
        image = each.value
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}


data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {

  for_each = var.service-image
  service     = google_cloud_run_service.run[each.key].name
  location    = google_cloud_run_service.run[each.key].location
  policy_data = data.google_iam_policy.noauth.policy_data
}


//  2.creation of endpoint groups
resource "google_compute_region_network_endpoint_group" "endpoint" {
  
  for_each = var.service-image
  name                  = each.key
  network_endpoint_type = "SERVERLESS"
  region                = "asia-south1"
  cloud_run {
    service = google_cloud_run_service.run[each.key].name
  }
}

//3.creation of backend service

resource "google_compute_backend_service" "backend" {
  for_each = var.service-image
  name     = each.key
  protocol  = "HTTP"
  port_name = "http"
  timeout_sec = 30
   backend {
    group = google_compute_region_network_endpoint_group.endpoint[each.key].id
   }
}  
