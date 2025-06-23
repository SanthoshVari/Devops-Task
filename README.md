# Flask App on EKS: My Journey with Terraform, ArgoCD, and GitHub Actions

Hey there! I want to walk you through how I set up a Flask application on an Amazon EKS cluster in `ap-south-1`. This project has been a fun ride, combining a bunch of cool tools like Terraform, Helm, ArgoCD, and GitHub Actions to make everything automated and secure. The Flask app is a simple web page showing the current date and a live-updating clock, but the real magic happens in how it’s deployed and monitored. I used Terraform to spin up the EKS cluster and enable CloudWatch Container Insights for observability, which gives me logs and metrics to keep an eye on things. The app runs on worker nodes in private subnets, with an EC2 instance in a public subnet for local testing and CI/CD tools. ArgoCD handles deployments via Helm charts, and a GitHub Actions pipeline automates testing, security scans (SonarCloud and Trivy), Docker builds, and email notifications. Oh, and I’ve got an AWS Lambda function to manage S3 reports, keeping only the latest three reports and archiving the rest. Let’s dive in!

## The Flask App and Dockerfile

### The App (`app.py`)
The heart of this project is a simple Flask app that displays today’s date and a live clock on a webpage. It’s straightforward but does the job for testing deployments.

```python
from flask import Flask, render_template_string
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def hello():
    today = datetime.now().strftime("%Y-%m-%d")
    # HTML with embedded JavaScript for live time
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Flask Time App</title>
        <script>
            function updateTime() {{
                const now = new Date();
                const time = now.toLocaleTimeString();
                document.getElementById("time").innerText = time;
            }}
            setInterval(updateTime, 1000);
        </script>
    </head>
    <body onload="updateTime()">
        <h2>Hello, This is a sample Flask Application!</h2>
        <p>Today's Date: <strong>{today}</strong></p>
        <p>Current Time: <strong id="time"></strong></p>
    </body>
    </html>
    """
    return render_template_string(html_content)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)


```

### The Dockerfile
To containerize the app, I wrote a Dockerfile using a lightweight Python 3.9 image. It’s super simple and exposes port 5000 for the Flask app.

```dockerfile

FROM python:3.9-slim


WORKDIR /app


COPY app.py .


RUN pip install --no-cache-dir flask

EXPOSE 5000


CMD ["python", "app.py"]

```

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Network Setup](#network-setup)
4. [Terraform Setup](#terraform-setup)
5. [EC2 Instance Setup](#ec2-instance-setup)
6. [ArgoCD Setup](#argocd-setup)
7. [Helm Charts](#helm-charts)
8. [ArgoCD Application](#argocd-application)
9. [Ingress and Readiness Probes](#ingress-and-readiness-probes)
10. [GitHub Actions CI/CD](#github-actions-cicd)
11. [AWS Lambda for Reports](#aws-lambda-for-reports)
12. [Observability](#observability)
13. [Security Practices](#security-practices)
14. [Next Steps](#next-steps)
15. [Secrets Used](#secrets-used)

## Overview
I built this project to deploy a Flask app on an EKS cluster in `ap-south-1`, with worker nodes in private subnets for security. I used Terraform to set up the cluster and enable CloudWatch Container Insights, which gives me awesome visibility into logs and metrics. The app is containerized and deployed using Helm charts, managed by ArgoCD for a GitOps workflow. The ArgoCD UI is exposed via a Classic Load Balancer, and the Flask app uses a Network Load Balancer (NLB) for external access, both routed through an Internet Gateway. I’ve got an EC2 instance in a public subnet for local testing and running CI/CD tools. The GitHub Actions pipeline handles everything from testing to security scans (SonarCloud and Trivy), Docker image builds, Helm updates, and email notifications. An AWS Lambda function keeps my S3 bucket tidy by archiving older reports, ensuring only the latest three reports of each type (SonarCloud, Trivy filesystem, Trivy image) stay in the main bucket.

## Prerequisites
Before diving in, you’ll need:
- **Tools**: AWS CLI, `kubectl`, `helm`, `terraform` (version 1.5.0 or higher), and Git on your EC2 instance and local machine.
- **AWS Setup**:
  - IAM roles for EKS, EC2, S3, Lambda, and VPC.
  - Security groups for SSH, HTTP/HTTPS, and Kubernetes.
  - An S3 bucket (`flask-eks-terraform-state`) and DynamoDB table (`terraform-locks`) for Terraform state locking.
- **GitHub Repo**: Hosts `app.py`, `Dockerfile`, Helm charts, and Terraform files at `https://github.com/SanthoshVari/Devops-task.git`.
- **GitHub Secrets**:
  - `SONAR_TOKEN`: For SonarCloud.
  - `DOCKER_USERNAME`, `DOCKER_PASSWORD`: For Docker Hub.
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`: For AWS access.
  - `TERRAFORM_STATE_BUCKET`: S3 bucket for Terraform state.
  - `MY_IP`: Your IP for security group rules.
  - `S3_BUCKET`: S3 bucket for scan reports.
  - `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `TO_EMAIL`: For email notifications.

## Network Setup
I set up a VPC in `ap-south-1` with public and private subnets to keep things secure and organized.

### Components
- **VPC**: CIDR `10.0.0.0/16`.
- **Public Subnets**:
  - `subnet-public-1` (`10.0.1.0/24`, `ap-south-1a`): Hosts EC2, NAT Gateway, Classic Load Balancer, NLB.
  - `subnet-public-2` (`10.0.2.0/24`, `ap-south-1b`): For high availability.
- **Private Subnets**:
  - `subnet-private-1` (`10.0.3.0/24`, `ap-south-1a`): EKS worker nodes.
  - `subnet-private-2` (`10.0.4.0/24`, `ap-south-1b`): For high availability.
- **Internet Gateway**: Lets public subnets access the internet.
- **NAT Gateway**: In `subnet-public-1`, allows private subnets to make outbound requests.
- **Route Tables**:
  - Public: Routes `0.0.0.0/0` to the Internet Gateway.
  - Private: Routes `0.0.0.0/0` to the NAT Gateway.
- **Security Groups**:
  - `sg-eks-control-plane`: Allows worker nodes and my IP to access the EKS API.
  - `sg-eks-worker-nodes`: Enables communication with the control plane and load balancers.
  - `sg-load-balancer`: Permits HTTP/HTTPS (ports 80, 443) from my IP.
  - `sg-ec2`: Allows SSH (port 22) and HTTP (port 5000) from my IP.

## Terraform Setup
I used Terraform to provision the EKS cluster and enable CloudWatch Container Insights, organizing everything into modules for reusability. I also set up state locking with an S3 bucket and DynamoDB to keep things safe in the CI/CD pipeline.

### Directory Structure
```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── backend.tf
├── modules/
│   ├── vpc/
│   ├── iam/
│   ├── eks/
│   ├── cloudwatch/
```

### Modules
- **VPC**: Sets up the VPC, subnets, Internet Gateway, NAT Gateway, and route tables.
- **IAM**: Creates roles for the EKS cluster and node group, including permissions for CloudWatch.
- **EKS**: Deploys the EKS cluster (version 1.29) with a node group (`t3.medium`, min=1, max=3, desired=2) in private subnets.
- **CloudWatch**: Installs CloudWatch Container Insights via Helm for logs and metrics.

### State Locking
To prevent conflicts in the CI/CD pipeline, I store the Terraform state in an S3 bucket (`flask-eks-terraform-state`) and use a DynamoDB table (`terraform-locks`) for locking.

1. **Create S3 Bucket**:
   ```bash
   aws s3api create-bucket --bucket flask-eks-terraform-state --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
   aws s3api put-bucket-versioning --bucket flask-eks-terraform-state --versioning-configuration Status=Enabled
   ```

2. **Create DynamoDB Table**:
   ```bash
   aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region ap-south-1
   ```

3. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init -backend-config="bucket=flask-eks-terraform-state" -backend-config="key=terraform/eks-flask-app/state.tfstate" -backend-config="region=ap-south-1" -backend-config="dynamodb_table=terraform-locks"
   ```

4. **Apply Configuration**:
   ```bash
   terraform plan -var="my_ip=YOUR_IP/32"
   terraform apply -var="my_ip=YOUR_IP/32"
   ```

### Outputs
You’ll get the VPC ID, subnet IDs, EKS cluster endpoint, and certificate authority data to configure `kubectl`.

## EC2 Instance Setup
I set up an EC2 instance in `subnet-public-1` to test the Flask app locally and run CI/CD tools.

### Steps
1. **Launch EC2 Instance**:
   - Use Amazon Linux 2 AMI, `t3.medium`.
   - Place in `subnet-public-1` with a public IP.
   - Assign `sg-ec2` (allows SSH on port 22, HTTP on port 5000).
   - Use a key pair for SSH.

2. **Connect**:
   ```bash
   ssh -i my-key-pair.pem ec2-user@<EC2_PUBLIC_IP>
   ```

3. **Install Tools**:
   ```bash
   sudo yum update -y
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
   sudo yum install git -y
   sudo yum install python39 -y
   pip3.9 install flask pytest
   curl -fsSL -o get_terraform.sh https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

4. **Configure AWS**:
   ```bash
   aws configure
   ```
   Enter `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` (`ap-south-1`).

5. **Clone Repo**:
   ```bash
   git clone https://github.com/SanthoshVari/Devops-task.git
   cd Devops-task
   ```

6. **Test Flask App**:
   ```bash
   python3.9 app.py
   ```
   Access it at `http://<EC2_PUBLIC_IP>:5000`.

## ArgoCD Setup
ArgoCD makes deployments a breeze with its GitOps approach. I set it up with a Classic Load Balancer for the UI.

### Steps
1. **Add Helm Repo**:
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   ```

2. **Create Namespace**:
   ```bash
   kubectl create namespace argocd
   ```

3. **Install ArgoCD**:
   ```bash
   helm install argocd argo/argo-cd --namespace argocd --set server.service.type=LoadBalancer
   ```

4. **Access UI**:
   - Update `sg-load-balancer` to allow ports 80/443 from your IP.
   - Get the endpoint:
     ```bash
     kubectl get svc -n argocd
     ```
   - Get the admin password:
     ```bash
     kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode && echo
     ```

## Helm Charts
My Helm chart for the Flask app lives in `K8s/charts/flask-app/` and hasn’t changed since the original setup. It’s ready to go with the Terraform-provisioned EKS cluster.

### Structure
```
K8s/
├── charts/
│   ├── flask-app/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
```
- **Chart.yaml**: Defines the chart name and version.
- **values.yaml**: Sets the image tag, resources, and NLB settings.
- **deployment.yaml**: Configures the Flask app pods, including replicas and readiness probes.
- **service.yaml**: Creates a `ClusterIP` service for internal access.
- **ingress.yaml**: Routes traffic via the NLB with TLS.

No changes were needed to these files, as they work seamlessly with the new EKS cluster.

## ArgoCD Application
I use an ArgoCD Application manifest to deploy the Flask app via Helm.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flask-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/SanthoshVari/devops-task.git
    targetRevision: main
    path: K8s/charts/flask-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

```

## Ingress and Readiness Probes
- **Ingress**: The `ingress.yaml` file sets up the NLB with TLS via `cert-manager`, deployed in `subnet-public-1` and `subnet-public-2`.
- **Readiness Probes**: Defined in `deployment.yaml` to ensure the Flask app is ready before receiving traffic.

## GitHub Actions CI/CD
The CI/CD pipeline runs on pushes to the `main` branch, automating everything from infrastructure to deployment.

<img src="assets/Devops-task CiCd pipeline.png" width="1000" height="780"/>

### Configuration
```yaml
on:
  push:
    branches: [main]
permissions:
  contents: write
  security-events: write
```

### Jobs
1. **terraform**: Sets up the EKS cluster and CloudWatch Insights using Terraform with state locking.
2. **build-and-test**: Runs `pytest` tests on the Flask app.
3. **sonarqube-scan**: Scans code with SonarCloud, uploads report to `s3://${{ secrets.S3_BUCKET }}/sonar/`.
4. **trivy-fs-scan**: Runs Trivy filesystem scan, uploads SARIF report to S3.
5. **docker-build-push**: Builds and pushes the Docker image to `SanthoshVari/flask-app:${{ github.run_number }}`, runs Trivy image scan, and uploads the report.
6. **archive-s3-reports**: Invokes the Lambda function to archive reports.
7. **argocd**: Updates `values.yaml` with the new image tag and commits to Git.
8. **send-email-notification**: Emails scan reports using SMTP.

### Workflow Snippet
```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.9'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install flask pytest

      - name: Run tests
        run: |
          pytest --version  # Replace with pytest tests/test_app.py

  sonarqube-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for SonarQube to analyze git history

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@v2
        with:
          args: >
            -Dsonar.projectKey=SanthoshVari_Devops-task-sonar
            -Dsonar.organization=santhoshvari
            -Dsonar.sources=.
            -Dsonar.projectVersion=${{ github.run_number }}
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      
      - name: Upload SonarQube report to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ${{ secrets.AWS_REGION }}
        run: |
          aws s3 cp .scannerwork/report-task.txt s3://${{ secrets.S3_BUCKET }}/sonarqube-report-${{ github.run_number }}.txt

```

## AWS Lambda for Reports
I created a Lambda function (`archive-old-reports`) to manage S3 reports, keeping only the latest three reports for SonarCloud and Trivy in `s3://${{ secrets.S3_BUCKET }}/{sonar,trivy}/` and moving older ones to `s3://${{ secrets.S3_BUCKET }}/archive/{sonar,trivy}/`.

### Lambda Logic
- **Input**: A JSON payload with the bucket name.
- **Logic**:
  - Lists objects in `sonar/` and `trivy/` prefixes.
  - Extracts build numbers from filenames (e.g., `sonar-report-123.json`).
  - Sorts reports by build number (newest first).
  - Keeps the top three reports per type.
  - Archives older reports to the `archive/` prefix.
- **Code** (Python):
  ```python
  import boto3
  import json

  def lambda_handler(event, context):
      s3 = boto3.client('s3')
      bucket = event['bucket']
      prefixes = ['sonar', 'trivy']
      
      for prefix in prefixes:
          response = s3.list_objects_v2(Bucket=bucket, Prefix=f'{prefix}/')
          reports = []
          for obj in response.get('Contents', []):
              key = obj['Key']
              build = int(key.split('-')[-1].split('.')[0])
              reports.append((build, key))
          
          reports.sort(reverse=True)
          
          for i, (build, key) in enumerate(reports):
              if i >= 3:
                  archive_key = f'archive/{key}'
                  s3.copy_object(Bucket=bucket, CopySource={'Bucket': bucket, 'Key': key}, Key=archive_key)
                  s3.delete_object(Bucket=bucket, Key=key)
      
      return {'statusCode': 200, 'body': 'Reports archived'}
  ```
- **IAM Role**: Needs `AmazonS3FullAccess`.
- **Trigger**:
  ```bash
  aws lambda invoke --function-name archive-old-reports --payload '{"bucket": "${{ secrets.S3_BUCKET }}"}' response.json
  ```

## Observability
I wanted to keep a close eye on how my Flask app is running on EKS, so I set up CloudWatch Container Insights using Terraform’s `cloudwatch` module. This gives me detailed metrics and logs for the cluster, nodes, and pods, making it easy to spot issues or performance bottlenecks.

### How It Works
- **Setup**: The `cloudwatch` module deploys the CloudWatch agent to the `amazon-cloudwatch` namespace via a Helm chart (`aws-cloudwatch-metrics` from `https://aws.github.io/eks-charts`). It’s configured with the EKS cluster name (`flask-eks-cluster`) and a service account (`cloudwatch-agent`).
- **Metrics**: Container Insights collects metrics like CPU usage, memory usage, network traffic, and pod restarts for the Flask app pods, worker nodes, and the entire cluster. I can view these in the AWS CloudWatch Console under **Container Insights**.
- **Logs**: It captures pod logs automatically, including stdout/stderr from my Flask app containers. These logs are stored in CloudWatch Logs under log groups like `/aws/containerinsights/flask-eks-cluster/application`. I can filter logs by pod name, namespace, or container to debug issues.
- **Accessing Insights**:
  - Go to the AWS CloudWatch Console.
  - Navigate to **Insights > Container Insights**.
  - Select the cluster (`flask-eks-cluster`) to see dashboards for pods, nodes, and services.
  - For logs, go to **Logs > Log Groups**, find `/aws/containerinsights/flask-eks-cluster/*`, and query logs using CloudWatch Logs Insights.
- **Benefits**: This setup gives me a clear view of resource usage and errors without needing to modify my Helm charts. I can set up alarms (e.g., for high CPU or pod crashes) to get notified of issues.

### Checking Observability
- Verify the agent is running:
  ```bash
  kubectl get pods -n amazon-cloudwatch
  ```
  Look for pods like `aws-cloudwatch-metrics-xxx`.
- Check metrics in the CloudWatch Console under **Container Insights**.
- Query logs:
  ```bash
  aws logs filter-log-events --log-group-name /aws/containerinsights/flask-eks-cluster/application --filter-pattern "flask-app"
  ```

## Security Practices
- Worker nodes are in private subnets, only accessible via load balancers.
- Security groups (`sg-load-balancer`, `sg-ec2`) are locked down to my IP.
- Terraform state is stored in S3 with DynamoDB locking for safety.
- ArgoCD uses RBAC, and I avoid long-term use of the `admin` account.
- NLB uses TLS with `cert-manager`.
- Secrets are rotated regularly.
- SonarCloud and Trivy ensure code and image security.

## Next Steps
- Add `pytest` tests for `app.py` to catch bugs early.
- Move secrets to AWS Secrets Manager for better rotation.
- Set up Slack notifications for pipeline failures.
- Create CloudWatch alarms for key metrics like CPU or pod restarts.

## Secrets Used
| Secret Name          | Purpose                                  |
|----------------------|------------------------------------------|
| `SONAR_TOKEN`        | SonarCloud authentication                |
| `DOCKER_USERNAME`     | Docker Hub username                      |
| `DOCKER_PASSWORD`    | Docker Hub password                      |
| `AWS_ACCESS_KEY_ID`  | AWS credentials for EKS, S3, Lambda      |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials                     |
| `AWS_REGION`         | AWS region (`ap-south-1`)               |
| `TERRAFORM_STATE_BUCKET` | S3 bucket for Terraform state       |
| `MY_IP`              | Your IP for security group access        |
| `S3_BUCKET`          | S3 bucket for reports                    |
| `SMTP_SERVER`        | SMTP server for notifications            |
| `SMTP_PORT`          | SMTP port                                |
| `SMTP_USERNAME`      | SMTP authentication username             |
| `SMTP_PASSWORD`      | SMTP authentication password             |
| `TO_EMAIL`           | Recipient email for reports              |

## Conclusion
This project has been a blast to put together! The Flask app runs smoothly on an EKS cluster provisioned with Terraform, and CloudWatch Container Insights keeps me in the loop with logs and metrics. ArgoCD and Helm make deployments effortless, while the GitHub Actions pipeline automates everything from testing to report archiving. The Lambda function keeps my S3 bucket organized, and the network setup with public/private subnets ensures security. I’m excited to keep tweaking this setup with more tests and alerts!
