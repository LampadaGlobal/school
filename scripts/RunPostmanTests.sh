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
sleep 5
cat /proc/self/cgroup
currentDockerContainer="$(basename "$(head /proc/self/cgroup)")"
echo "currentDockerContainer $currentDockerContainer"

currentDockerContainer="2.session"
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

curl http://127.0.0.1/sugar

curl http://127.0.0.1/sugar/

curl http://localhost/sugar

curl http://localhost/sugar/

curl localhost/sugar/index.php

curl http://sugar-web1/sugar

cd workspace/sugardocker/data/app/sugar
ls


######################################################################
# Cleanup
######################################################################

if [[ -n $currentDockerContainer ]]
then
    #TODO: customize the stack
    docker network disconnect sugar710_default $currentDockerContainer
fi
