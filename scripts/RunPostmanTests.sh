#!/usr/bin/env bash

if [[ -z $SUGAR_LICENSE_KEY ]]
then
    echo "ERROR: The SUGAR_LICENSE_KEY environment variable is not set, so the Postman tests could not be run."
    exit 1
fi

######################################################################
# Setup
######################################################################

# Install Newman, so we can execute the tests
npm install -g newman


######################################################################
# Run the Postman tests
######################################################################

echo
echo "curl http://localhost/sugar"
curl http://localhost/sugar

echo
echo "curl http://localhost/sugar/"
curl http://localhost/sugar/

echo
echo "curl http://localhost:80/sugar/"
curl http://localhost:80/sugar/

echo
echo "curl http://sugar-web1/sugar/"
curl http://sugar-web1/sugar/

echo
echo "curl http://localhost/sugar/rest/v10/oauth2/token"
curl http://localhost/sugar/rest/v10/oauth2/token

newman run ../data/ProfessorM_PostmanCollection.json -e ../data/ProfessorM_PostmanEnvironment.json
