#!/bin/bash
#echo ECS_CLUSTER=pcg-ecs-cluster >> /etc/ecs/ecs.config
#!/bin/bash

# Update all packages

# sudo yum update -y
# sudo dnf install ecs-init -y
# sudo systemctl enable ecs
# sudo systemctl start ecs
# #sudo service docker start


# #Adding cluster name in ecs config
# echo ECS_CLUSTER=pcg-ecs-cluster >> /etc/ecs/ecs.config
# cat /etc/ecs/ecs.config | grep "ECS_CLUSTER"

#!/bin/bash

# Update the system
sudo dnf update -y

# Install Docker (required by ECS agent)
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker

# Add the ec2-user to the docker group
sudo usermod -a -G docker ec2-user

# Download the ECS agent configuration file
sudo mkdir -p /etc/ecs
echo "ECS_CLUSTER=pcg-ecs-cluster" | sudo tee /etc/ecs/ecs.config

# Pull and run the Amazon ECS agent Docker container
sudo docker run --name ecs-agent --detach --restart=always \
  --network=host \
  --volume=/var/run:/var/run:Z \
  --volume=/var/log/ecs:/log:Z \
  --volume=/var/lib/ecs:/data:Z \
  --volume=/etc/ecs:/etc/ecs:Z \
  --platform=linux/amd64 \
  --env-file=/etc/ecs/ecs.config \
  amazon/amazon-ecs-agent:latest

# Print ECS agent status
sudo docker ps | grep ecs-agent

