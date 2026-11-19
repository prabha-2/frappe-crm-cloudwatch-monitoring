# Frappe CRM on AWS EC2 with CloudWatch Monitoring

Deployed Frappe CRM on an EC2 instance with Docker Compose and monitored it
with CloudWatch: dashboard, application logs, metrics, and an email alert
for high CPU.



## Environment
- AWS region: ap-southeast-2 (Sydney)
- Instance: c7i-flex.large, Ubuntu, 20 GB EBS
- App: Frappe CRM, run with Docker Compose (frappe, mariadb, redis)
- Source: the course repo `frappe-crm-devops-internship` (`docker/` folder)

## Architecture

    EC2 (Docker containers)
      |-- CloudWatch Agent --> logs, memory, disk
      |-- cron script ------> container health counts (custom metrics)
      v
    CloudWatch (dashboard, alarms) --> SNS --> email

## What I did

1. **Deployed the app.** Cloned the course repo and ran `docker compose up -d`.
2. **Fixed a database error.** The first start failed with
   `TLS/SSL error: SSL is required, but the server does not support it`.
   The site was created with no tables, so every request returned an error.
   I made the MariaDB client skip SSL for the local connection by adding one
   line to `docker/init.sh` (see `docker/init.sh.diff`) and rebuilt the stack.
3. **Added health checks** to all three containers using a compose override
   file (`docker/docker-compose.override.yml`), so Docker reports each
   container as healthy or unhealthy.
4. **Created an IAM role** with CloudWatch agent permissions and attached it
   to the instance.
5. **Installed the CloudWatch agent**
   (`cloudwatch/amazon-cloudwatch-agent.json`) to send Docker container logs,
   memory usage and disk usage.
6. **Added a script and a cron job** (`cloudwatch/docker-health-metric.sh`,
   `cloudwatch/docker-health.cron`) that send custom metrics every minute:
   HealthyContainers, UnhealthyContainers and ExitedContainers
   (namespace `FrappeCRM`).
7. **Created an SNS topic** with an email subscription.
8. **Created two alarms:**
   - `frappe-crm-cpu-high`: CPU >= 80% for 2 consecutive 5-minute periods
   - Instance status alarm: StatusCheckFailed
9. **Built a dashboard** `frappe-crm` with CPU and status checks, memory and
   disk, container health, alarm status, and the application log table.

## Result

Containers after about an hour of running:

```
NAMES           STATUS
crm-frappe-1    Up About an hour (healthy)
crm-mariadb-1   Up About an hour (healthy)
crm-redis-1     Up About an hour (healthy)
```

Test: I ran `stress-ng --cpu 2 --timeout 900` on the instance. The CPU alarm
moved from OK to In alarm and an alert email arrived.

## Source and credits

- Application: [Frappe CRM](https://github.com/frappe/crm), an open-source
  project by Frappe Technologies. I did not write the application. See the
  upstream repository for its license.
- Docker setup: the `docker/` folder of the Frappe CRM repository.
- My work in this repo: the container health checks, the one-line SSL fix for
  `init.sh`, the CloudWatch agent config, the container health metric script,
  and the alarms and dashboard described below. The application source and
  the original `docker-compose.yml` are not copied here.



## Limitations
- There is no alarm on UnhealthyContainers yet. That metric is on the
  dashboard only.
- The MariaDB health check logs repeated `Access denied for user 'root'`
  warnings because it pings without a password. They are harmless but noisy.
- Disk was about 85% used on the 20 GB volume.
- Lab setup only: default CRM credentials, port 8000 open to my IP only,
  no HTTPS.

  ## How to reproduce

1. Clone [Frappe CRM](https://github.com/frappe/crm) and go to its `docker/` folder.
2. Add the line from `docker/init.sh.diff` to `init.sh`.
3. Copy `docker/docker-compose.override.yml` into the same folder.
4. Run `docker compose up -d` on an EC2 instance.
5. Attach an IAM role that lets the instance send logs and metrics to
   CloudWatch, install the CloudWatch agent with
   `cloudwatch/amazon-cloudwatch-agent.json`, and install the script and cron
   job from the `cloudwatch/` folder.
6. Create the SNS topic, alarms and dashboard in the console.