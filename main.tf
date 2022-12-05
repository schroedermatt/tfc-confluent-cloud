provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key 
  cloud_api_secret = var.confluent_cloud_api_secret

  # export CONFLUENT_CLOUD_API_KEY="<cloud_api_key>"
  # export CONFLUENT_CLOUD_API_SECRET="<cloud_api_secret>"
}

resource "confluent_environment" "workshop" {
  display_name = "Improving Workshop"
}

resource "confluent_kafka_cluster" "dev-cluster" {
  display_name = "development"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  basic {}

  environment {
    id = confluent_environment.workshop.id
  }
}

resource "confluent_service_account" "app-manager" {
  display_name = "app-manager"
  description  = "Service account to manage 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}

resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.dev-cluster.id
  }
  topic_name         = "orders"
  partitions_count   = 3
  rest_endpoint      = confluent_kafka_cluster.dev-cluster.rest_endpoint
  # config = {
  #   "cleanup.policy"    = "compact"
  #   "max.message.bytes" = "12345"
  #   "retention.ms"      = "67890"
  # }
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }

  lifecycle {
    prevent_destroy = true
  }
}
