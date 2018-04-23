#!/usr/bin/env bash

if [[ -z $SUGAR_LICENSE_KEY ]]
then
    echo "ERROR: The SUGAR_LICENSE_KEY environment variable is not set, so the Postman tests could not be run."
    exit 1
fi

######################################################################
# Setup
######################################################################

# Pull the Newman Docker container so we can run the tests
docker pull postman/newman_ubuntu1404

currentDockerContainer="$(cat /etc/hostname)"
cat /proc/self/cgroup
currentDockerContainer="$(basename "$(head /proc/self/cgroup)")"
echo "currentDockerContainer $currentDockerContainer"

if [[ -n $currentDockerContainer ]]
then
    #TODO: customize the stack
    echo "Updating the Docker network..."
    docker network connect sugar710_default $currentDockerContainer
fi

netstat -tulpn

while ! mysqladmin ping -h 127.0.0.1; do
    sleep 1
done

######################################################################
# Run the Postman tests
######################################################################

#TODO:  customize the volume
# works locally and in jenkins
#docker run -v /Users/lschaefer/git/school/data:/etc/newman --net="host" -t postman/newman_ubuntu1404 run "ProfessorM_PostmanCollection.json" --environment="ProfessorM_PostmanEnvironment.json"


# testing for Travis
echo $(pwd)
echo $(pwd)/../data
docker run -v $(pwd)/../data:/etc/newman -t postman/newman_ubuntu1404 run "ProfessorM_PostmanCollection.json" --environment="ProfessorM_PostmanEnvironment.json"

cat /proc/self/cgroup

docker ps

docker inspect $HOSTNAME

docker network inspect sugar710_default

docker network ls

docker network inspect host

sleep 15

curl -v4 http://127.0.0.1/sugar

curl -v4 http://127.0.0.1/sugar/

curl -v4 http://localhost/sugar

curl -v4 http://localhost/sugar/

curl -v4 localhost/sugar/index.php

curl -v4 http://sugar-web1/sugar

cd workspace/sugardocker/data/app/sugar
ls

docker exec sugar-web1 bash -c "pwd"

docker exec sugar-web1 bash -c "ls"

######################################################################
# Cleanup
######################################################################

if [[ -n $currentDockerContainer ]]
then
    #TODO: customize the stack
    docker network disconnect sugar710_default $currentDockerContainer
fi
