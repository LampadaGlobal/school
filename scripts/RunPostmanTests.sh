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
if [[ -n $currentDockerContainer ]]
then
    #TODO: customize the stack
    echo "Updating the Docker network..."
    docker network connect sugar710_default $currentDockerContainer
fi

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

######################################################################
# Cleanup
######################################################################

if [[ -n $currentDockerContainer ]]
then
    #TODO: customize the stack
    docker network disconnect sugar710_default $currentDockerContainer
fi
