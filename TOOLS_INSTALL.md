# Tools Installation & Version Verification

## 1. Update Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
```

Install basic utilities:

## 1. Update Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
```

Install required utilities and dependencies:

```bash
sudo apt install -y \
  curl \
  wget \
  git \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  python3 \
  coreutils
```

Verify:

```bash
curl --version
python3 --version
base64 --version
git --version
unzip -v | head -1
```

---

## 2. Install Docker

### Remove old Docker packages

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
```

### Add Docker repository

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Install Docker

```bash
sudo apt update

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

### Start Docker

```bash
sudo systemctl enable --now docker
```

### Verify Docker

```bash
docker --version
```

Check service:

```bash
sudo systemctl is-active docker
```

Expected:

```text
active
```

Test:

```bash
sudo docker run --rm hello-world
```

### Run Docker without sudo

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

Verify:

```bash
docker version
docker run --rm hello-world
```

---

## 3. Install kubectl

Download the latest stable version:

```bash
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

curl -LO \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
```

Install:

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Remove downloaded file:

```bash
rm kubectl
```

### Verify kubectl

```bash
kubectl version --client
```

Expected:

```text
Client Version: v1.xx.x
```

---

## 4. Install Minikube

Download:

```bash
curl -LO \
  https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

Install:

```bash
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

Remove downloaded file:

```bash
rm minikube-linux-amd64
```

### Verify Minikube

```bash
minikube version
```

Expected:

```text
minikube version: v...
```

---

## 5. Install Helm

Add Helm signing key:

```bash
curl https://baltocdn.com/helm/signing.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
```

Add repository:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
```

Install:

```bash
sudo apt update
sudo apt install -y helm
```

### Verify Helm

```bash
helm version --short
```

Expected:

```text
v3.x.x
```

---

## 6. Install Terraform

Add HashiCorp GPG key:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

Add repository:

```bash
echo \
  "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Install:

```bash
sudo apt update
sudo apt install -y terraform
```

### Verify Terraform

```bash
terraform version
```

Expected:

```text
Terraform v1.x.x
on linux_amd64
```

---

## 7. Verify curl

```bash
curl --version
```

Test connectivity:

```bash
curl -I https://www.google.com
```

Expected:

```text
HTTP/2 200
```

---

# 8. Final Version Check

Run all checks together:

```bash
echo "===== Docker ====="
docker --version

echo "===== Minikube ====="
minikube version

echo "===== kubectl ====="
kubectl version --client

echo "===== Helm ====="
helm version --short

echo "===== Terraform ====="
terraform version

echo "===== curl ====="
curl --version | head -1

echo "===== Git ====="
git --version
```

Expected:

```text
Docker      PASS
Minikube    PASS
kubectl     PASS
Helm        PASS
Terraform   PASS
curl        PASS
Git         PASS
```

**Installation complete.**
