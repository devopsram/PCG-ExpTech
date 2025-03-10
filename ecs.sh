#!/bin/bash
#echo ECS_CLUSTER=pcg-ecs-cluster >> /etc/ecs/ecs.config
#!/bin/bash

# Update all packages

sudo yum update -y
sudo dnf install ecs-init
sudo systemctl enable ecs
sudo systemctl start ecs
#sudo service docker start


#Adding cluster name in ecs config
echo ECS_CLUSTER=pcg-ecs-cluster >> /etc/ecs/ecs.config
cat /etc/ecs/ecs.config | grep "ECS_CLUSTER"
