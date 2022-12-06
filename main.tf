provider "confluent" {
  # export TF_VAR_confluent_cloud_api_key="***REDACTED***"
  # export TF_VAR_confluent_cloud_api_secret="***REDACTED***"

  # cloud_api_key    = var.confluent_cloud_api_key
  # cloud_api_secret = var.confluent_cloud_api_secret
}

resource "confluent_environment" "workshop" {
  display_name = "ImprovingWorkshop"
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

resource "confluent_service_account" "env-manager" {
  display_name = "env-manager"
  description  = "Service account to manage 'dev-cluster' Kafka cluster"
}

resource "confluent_role_binding" "env-manager-cloud-cluster-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dev-cluster.rbac_crn
}

resource "confluent_api_key" "env-manager-kafka-api-key" {
  display_name = "env-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dev-cluster.id
    api_version = confluent_kafka_cluster.dev-cluster.api_version
    kind        = confluent_kafka_cluster.dev-cluster.kind

    environment {
      id = confluent_environment.workshop.id
    }
  }

  depends_on = [
    confluent_role_binding.env-manager-cloud-cluster-admin
  ]
}

resource "confluent_kafka_topic" "orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.dev-cluster.id
  }
  topic_name         = "${var.workshop-topic-prefix}-orders"
  partitions_count   = 3
  rest_endpoint      = confluent_kafka_cluster.dev-cluster.rest_endpoint
  # config = {
  #   "cleanup.policy"    = "compact"
  #   "max.message.bytes" = "12345"
  #   "retention.ms"      = "67890"
  # }
  credentials {
    key    = confluent_api_key.env-manager-kafka-api-key.id
    secret = confluent_api_key.env-manager-kafka-api-key.secret
  }

  lifecycle {
    prevent_destroy = true
  }
}

####
# ACLs

resource "confluent_kafka_acl" "app-producer-write-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.dev-cluster.id
  }
  resource_type = "TOPIC"
  resource_name = var.workshop-topic-prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.dev-cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.env-manager-kafka-api-key.id
    secret = confluent_api_key.env-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-consumer-read-on-topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.dev-cluster.id
  }
  resource_type = "TOPIC"
  resource_name = var.workshop-topic-prefix
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.dev-cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.env-manager-kafka-api-key.id
    secret = confluent_api_key.env-manager-kafka-api-key.secret
  }
}

resource "confluent_kafka_acl" "app-consumer-read-on-group" {
  kafka_cluster {
    id = confluent_kafka_cluster.dev-cluster.id
  }
  resource_type = "GROUP"
  // The existing values of resource_name, pattern_type attributes are set up to match Confluent CLI's default consumer group ID ("confluent_cli_consumer_<uuid>").
  // https://docs.confluent.io/confluent-cli/current/command-reference/kafka/topic/confluent_kafka_topic_consume.html
  // Update the values of resource_name, pattern_type attributes to match your target consumer group ID.
  // https://docs.confluent.io/platform/current/kafka/authorization.html#prefixed-acls
  resource_name = "confluent_cli_consumer_"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.app-consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.dev-cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.env-manager-kafka-api-key.id
    secret = confluent_api_key.env-manager-kafka-api-key.secret
  }
}

####
# PRODUCER

resource "confluent_service_account" "app-producer" {
  display_name = "app-producer"
}

resource "confluent_api_key" "app-producer-kafka-api-key" {
  display_name = "app-producer-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-producer' service account"
  owner {
    id          = confluent_service_account.app-producer.id
    api_version = confluent_service_account.app-producer.api_version
    kind        = confluent_service_account.app-producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dev-cluster.id
    api_version = confluent_kafka_cluster.dev-cluster.api_version
    kind        = confluent_kafka_cluster.dev-cluster.kind

    environment {
      id = confluent_environment.workshop.id
    }
  }
}

####
# CONSUMER

resource "confluent_service_account" "app-consumer" {
  display_name = "app-consumer"
}

resource "confluent_api_key" "app-consumer-kafka-api-key" {
  display_name = "app-consumer-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-consumer' service account"
  owner {
    id          = confluent_service_account.app-consumer.id
    api_version = confluent_service_account.app-consumer.api_version
    kind        = confluent_service_account.app-consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dev-cluster.id
    api_version = confluent_kafka_cluster.dev-cluster.api_version
    kind        = confluent_kafka_cluster.dev-cluster.kind

    environment {
      id = confluent_environment.workshop.id
    }
  }
}
