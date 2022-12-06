# Terraform Cloud + Confluent Cloud

This project is wired up with Terraform Cloud and will automatically be applied on commits to `main`.

## Apply

```bash
> export TF_VAR_confluent_cloud_api_key="***REDACTED***"
> export TF_VAR_confluent_cloud_api_secret="***REDACTED***"
> terraform apply
> terraform output resource-ids
```