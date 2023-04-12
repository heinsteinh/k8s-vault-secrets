# Uncomment this to have Agent run once (e.g. when running as an initContainer)
#exit_after_auth = true
pid_file = "/home/vault/pidfile"
auto_auth {
    method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
            role = "internal-app"
        }
    }
    sink "file" {
        config = {
            path = "/home/vault/.vault-token"
        }
    }
}
template {
  destination = "/etc/secrets/index.html"
  contents = <<EOH
  <html>
  <body>
  <p>DB Connection String:</p>
  {{- with secret "internal/data/database/config" -}}
  postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@postgres:5432/wizard
  {{ end }}
  </body>
  </html>
  EOH
}
