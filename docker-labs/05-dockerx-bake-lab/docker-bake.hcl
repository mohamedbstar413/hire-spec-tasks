group "default" {
  targets = ["frontend", "backend", "worker"]
}

target "frontend" {
  context = "./frontend"
  dockerfile = "Dockerfile"
  tags = ["hire-spec/frontend:latest"]
}

target "backend" {
  context = "./backend"
  dockerfile = "Dockerfile"
  tags = ["myorg/backend:latest"]
}

target "database" {
  context = "./database"
  dockerfile = "Dockerfile"
  tags = ["myorg/worker:latest"]
}
