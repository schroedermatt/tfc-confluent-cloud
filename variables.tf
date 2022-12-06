# variable "confluent_cloud_api_key" {
#   description = "Confluent Cloud API Key (also referred as Cloud API ID) with EnvironmentAdmin permissions provided by Kafka Ops team"
#   type        = string
# }

# variable "confluent_cloud_api_secret" {
#   description = "Confluent Cloud API Secret"
#   type        = string
#   sensitive   = true
# }

variable "workshop-topic-prefix" {
  default = "data-demo"
}
