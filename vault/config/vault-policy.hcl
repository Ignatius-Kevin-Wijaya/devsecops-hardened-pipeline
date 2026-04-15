path "secret/data/ci/*" {
  capabilities = ["read"]
}

path "database/creds/ci-role" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
