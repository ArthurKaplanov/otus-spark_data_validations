resource "yandex_iam_service_account" "sa" {
  name        = var.yc_service_account_name
  description = "The service account for data validations training"
}

resource "yandex_resourcemanager_folder_iam_member" "sa_roles" {
  for_each = toset([
    "iam.serviceAccounts.user",
    "compute.admin",
    "dataproc.editor",
    "dataproc.agent",
    "mdb.dataproc.agent",
    "vpc.admin",
    "storage.uploader",
    "storage.viewer",
    "storage.editor"
  ])

  folder_id = var.yc_folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_key" "hw3_auth_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "The new auth key for data validations a. k. hw3"
}

resource "local_sensitive_file" "authorized_key_json" {
  filename = "${path.module}/../infra/authorized_key.json"

  content = jsonencode({
    id                 = yandex_iam_service_account_key.hw3_auth_key.id
    service_account_id = yandex_iam_service_account.sa.id
    created_at         = yandex_iam_service_account_key.hw3_auth_key.created_at
    key_algorithm      = yandex_iam_service_account_key.hw3_auth_key.key_algorithm
    public_key         = yandex_iam_service_account_key.hw3_auth_key.public_key
    private_key        = yandex_iam_service_account_key.hw3_auth_key.private_key
  })
}