  provider "google" {
  credentials = file("searce-msp-gcp-6bcc0aec066a.json")
  project = "searce-msp-gcp"
  region  = "asia-south1"
  zone    = "asia-south1-a"
}
// Cloud Run Example



 // 1. Creation of cloud run service
resource "google_cloud_run_service" "dev" {

 
  for_each = var.service-image
  name  = each.key
  
  location = "asia-south1"

   template {
    spec {
       service_account_name = "cloud-run-az@searce-msp-gcp.iam.gserviceaccount.com" 
            
    
      containers {
    
        image = each.value
        resources {
          limits = {
            cpu = "1000m"
            memory = "512M"
          }
        }
        
      }
    }
    metadata {
      annotations = {
        # limit scale up to prevent any cost blow outs!
        "autoscaling.knative.dev/maxScale" = "5"
        "autoscaling.knative.dev/minScale" = "0"
        # use the VPC Connector above
        "run.googleapis.com/vpc-access-connector" ="az-vpc-connector"
        # all egress from the service should go through the VPC Connector
        "run.googleapis.com/vpc-access-egress" = "all"
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




////////////////////////

# creation of cloudrun + vpc connector + NAT gateway

# provider "google" {
#   version = "~> 3.46.0"
#   region  = var.region
#   project = var.project_id
# }

# resource "google_vpc_access_connector" "connector" {
#   name          = "vpcconn"
#   region        = var.region
#   # e.g. "10.8.0.0/28"
#   ip_cidr_range = var.serverless_vpc_conn_cidr
#   network       = var.network
# }

# resource "google_compute_router" "router" {
#   name    = "router"
#   project = var.project_id
#   region  = var.region
#   network = var.network
# }

# resource "google_compute_router_nat" "nat" {
#   name                               = "nat"
#   project                            = var.project_id
#   region                             = var.region
#   router                             = google_compute_router.router.name
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#   nat_ip_allocate_option             = "AUTO_ONLY"
# }

# resource "google_cloud_run_service" "gcr_service" {
#   name     = "mygcrservice"
#   location = var.region

#   template {
#     spec {
#       containers {
#         image = var.myservice_image
#         resources {
#           limits = {
#             memory = "512M"
#           }
#         }
#       }
#       # the service itself uses this SA to call other GCP APIs etc
#       service_account_name = var.myservice_runtime_sa
#     }

#     metadata {
#       annotations = {
#         # limit scale up to prevent any cost blow outs!
#         "autoscaling.knative.dev/maxScale" = "5"
#         # use the VPC Connector above
#         "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
#         # all egress from the service should go through the VPC Connector
#         "run.googleapis.com/vpc-access-egress" = "all"
#       }
#     }
#   }
#   autogenerate_revision_name = true
# }
