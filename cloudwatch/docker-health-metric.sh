#!/bin/bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
H=$(docker ps --filter health=healthy -q | wc -l)
U=$(docker ps --filter health=unhealthy -q | wc -l)
X=$(docker ps -a --filter status=exited -q | wc -l)
for m in "HealthyContainers:$H" "UnhealthyContainers:$U" "ExitedContainers:$X"; do
  aws cloudwatch put-metric-data --region "$REGION" --namespace FrappeCRM \
    --metric-name "${m%%:*}" --dimensions InstanceId="$IID" --value "${m##*:}"
done