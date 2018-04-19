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
    docker network connect sugar710_default $currentDockerContainer
    docker network inspect sugar710_default
fi

######################################################################
# Run the Postman tests
######################################################################

#TODO:  customize the volume
docker run -v /Users/lschaefer/git/school/data:/etc/newman --net="host" -t postman/newman_ubuntu1404 run "ProfessorM_PostmanCollection.json" --environment="ProfessorM_PostmanEnvironment.json"
