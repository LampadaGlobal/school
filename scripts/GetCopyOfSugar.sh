#!/usr/bin/env bash

# This script gets a copy of Sugar from the designated directory or downloads a Sugar dev build from the Sugar Store
# or the SugarCRM Developer Builds community.
#
# Note: you must have access to the Sugar Store (https://store.sugarcrm.com/download) and/or the SugarCRM Developer
# Builds community (https://community.sugarcrm.com/community/developer/developer-builds) depending on where the build is
# stored in order for the download to be successful.


######################################################################
# Variables
######################################################################

if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]] || [[ -z "$4" ]]
then
    echo "Not all required command line arguments were set. Please run the script again with the required arguments:
        1: Email address associated with your SugarCRM account
        2: Password associated with the above account
        3: Sugar name (For example: SugarEnt-7.11)
        4. The path to where the Sugar download should be stored
        5. (Optional) Path to where Sugar source zip files are stored. If this param is not provided, the Sugar
           source zip files will be downloaded from the SugarCRM Developer Builds Community.  The Sugar source zip files
           should be named with the following pattern: Sugar$sugarEdition-$sugarVersion. For example: SugarEnt-7.11

        For example: ./GetCopyOfSugar.sh email@example.com mypassword SugarEnt-7.11 workspace/sugardocker/data/app ../sugar_source_zips"
    exit 1
fi

# Email address associated with your SugarCRM account
email=$1

# Password associated with your SugarCRM account
password=$2

# The Sugar name (For example: SugarEnt-7.11)
sugarName=$3

# The path to where the Sugar download should be stored
sugarDirectory=$4

# Path to where existing Sugar source zip files are stored
sugarSourceZipsDirectory=$5

# The path to the cookie jar file (relative to the Sugar directory) where the cookies required for this script will be stored
cookieFile="./mycookie"


######################################################################
# Functions
######################################################################

# Check that the status code in the response matches what is expected
# $1: expected status code
# $2: response from curl command
checkStatusCode(){
    regexStatusCode=".*HTTP/1.1 ([^[:space:]]*).*"

    if [[ $2 =~ $regexStatusCode ]]
    then
        statusCode="${BASH_REMATCH[1]}"
        if [[ "$statusCode" == $1 ]]
        then
            return
        else
            echo "Status code is not the expected $1: $statusCode"
            echo "$2"
            exit 1
        fi
    else
        echo "Unable to find status code in response: $2"
        exit 1
    fi
}

# Print the value of the Location included in the response
# $1: response from curl command
getLocationFromResponse(){
    regexLocation=".*Location: ([^[:space:]]*).*"

    if [[ $1 =~ $regexLocation ]]
    then
        location="${BASH_REMATCH[1]}"
        echo "$location"
    else
        echo "Unable to find location in response"
        exit 1
    fi
}

# Print the value associated with a given key for a JSON response
# $1: The key associated with the JSON value you want to parse
# $2: response from curl command
getJsonValueFromResponse(){
    regexJsonValue="$1\":\"([^\"]*)\""

    if [[ $2 =~ $regexJsonValue ]]
    then
        value="${BASH_REMATCH[1]}"
        echo "$value"
    else
        echo "Unable to find the value of $1 in response"
        echo $2
        exit 1
    fi
}

# Print the Sugar Download ID associated with the given Sugar zip file
# $1: The name of the Sugar zip file to search for in the response
# $2: response from curl command
getSugarDownloadIdFromResponse(){
    # This regex parses a string similar to
    # "id":"download-id-we-are-trying-to-get","name":"SugarEnt-7.9.3.0.zip"
    regexJasonValue="\"id\":\"([^\"]*)\",\"name\":\"$1\""

    if [[ $2 =~ $regexJasonValue ]]
    then
        value="${BASH_REMATCH[1]}"
        echo "$value"
    else
        echo "Unable to find the value of $1 in response"
        echo $2
        exit 1
    fi
}

# Print the value associated with a hidden form field
# $1: name of the hidden form field
# $2: response from curl command
getHiddenFormFieldValue(){
    regexToken=".*name=\"$1\" value=\"([^\"]*).*"

    if [[ $response =~ $regexToken ]]
    then
        value="${BASH_REMATCH[1]}"

        # This is a hack specifically for Travis CI.  Travis CI outputs a string like the following in the middle
        # of the SAML Response:
        #
        # 100 12223    0 12223    0     0  16084      0 --:--:-- --:--:-- --:--:-- 16104
        # * Connection #0 to host auth.sugarcrm.com left intact
        #
        # This Regex Token pulls this junk out of the SAML Response
        newLineRegexToken="(.*)[[:space:]]+[[:digit:]][[:digit:]][[:digit:]][[:space:]].*intact[[:space:]]*(.*)"
        if [[ $1 == 'SAMLResponse' && $value =~ $newLineRegexToken ]]
        then
            value="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
        fi

        echo $value
    else
        echo "Unable to find $2 in response"
        echo "$2"
        exit 1
    fi
}

# Authenticate to the Sugar Store and print the URL to download the given Sugar zip
# $1: The name of zip to download (for example: SugarEnt-7.9.3.0.zip)
function authenticateToSugarStoreAndGetDownloadUrl(){

    response="$(curl -v -L -c $cookieFile -b $cookieFile 'https://store.sugarcrm.com/download' 2>&1)"
    checkStatusCode "200" "$response"
    token="$(getHiddenFormFieldValue "_token" "$response")"

    response="$(curl -v -L -c $cookieFile -b $cookieFile --data "_token=$token&email=$email&password=$password" https://auth.sugarcrm.com/auth/login 2>&1)"
    checkStatusCode "200" "$response"
    accountId="$(getJsonValueFromResponse "id" "$response")"

    response="$(curl -v -L -c $cookieFile -b $cookieFile "https://store.sugarcrm.com/api/v1/accounts/$accountId/downloads" 2>&1)"
    checkStatusCode "200" "$response"
    downloadId="$(getSugarDownloadIdFromResponse $1 "$response")"
    hash="$(getJsonValueFromResponse "hash" "$response")"

    downloadUrl="https://store.sugarcrm.com/download/$downloadId/$hash"
    echo $downloadUrl
}

# Authenticate to the Developer Builds Community
function authenticateToDevBuildsCommunity(){

    response="$(curl -v -L -c $cookieFile -b $cookieFile 'https://community.sugarcrm.com/login.jspa?ssologin=true&fragment=&referer=%2Fcommunity%2Fdeveloper%2Fdeveloper-builds' 2>&1)"
    checkStatusCode "200" "$response"
    token="$(getHiddenFormFieldValue "_token" "$response")"

    response="$(curl -v -L -c $cookieFile -b $cookieFile --data "_token=$token&email=$email&password=$password" https://auth.sugarcrm.com/saml2/idp/authpage?ReturnTo=https%3A%2F%2Fauth.sugarcrm.com%2Fsaml2%2Fidp%2FSSOService%3Fspentityid%3Dhttps%253A%252F%252Fcommunity.sugarcrm.com%26RelayState%3DL2NvbW11bml0eS9kZXZlbG9wZXIvZGV2ZWxvcGVyLWJ1aWxkcw%253D%253D 2>&1)"
    checkStatusCode "200" "$response"
    samlResponse="$(getHiddenFormFieldValue "SAMLResponse" "$response")"

    response="$(curl -v -L -c $cookieFile -b $cookieFile --data-urlencode "SAMLResponse=$samlResponse" --data-urlencode "RelayState=L2NvbW11bml0eS9kZXZlbG9wZXIvZGV2ZWxvcGVyLWJ1aWxkcw==" 'https://community.sugarcrm.com/saml/sso' 2>&1)"
    checkStatusCode "200" "$response"
}


######################################################################
# Check if we have a copy of the Sugar source zip already downloaded
######################################################################

# If we already have a copy of the Sugar source zip, we'll copy it to the Sugar directory and exit the script
if [[ -d "$sugarSourceZipsDirectory" && -e "$sugarSourceZipsDirectory/$sugarName.zip" ]]
then
    echo "$sugarSourceZipsDirectory/$sugarName.zip already exists. A new copy of Sugar will not be downloaded."

    cp $sugarSourceZipsDirectory/$sugarName.zip $sugarDirectory/$sugarName.zip
    exit 0
fi


######################################################################
# Setup for download
######################################################################

# Change to the Sugar directory
cd $sugarDirectory

# Delete the cookie jar file if it exists
rm -f $cookieFile

# Set the file permissions for when sudo is required and is not required
chmod -R 777 .
sudo chmod -R 777 .


#######################################################################
# Get the URL to download and authenticate to the appropriate location
#######################################################################

sugarVersion_7_10="7.10"
sugarVersion_7_11="7.11"
sugarVersion_8_0="8.0"

sugarEdition_Ult="Ult"
sugarEdition_Ent="Ent"
sugarEdition_Pro="Pro"

# Get the url for the appropriate Sugar version and edition as well as
# authenticate to the appropriate location (Sugar Store or Developer Builds Community)
if [[ "$sugarName" == "Sugar$sugarEdition_Ult-$sugarVersion_7_10" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/4930-102-2-6967/SugarUlt-7.10.0.0-dev.1.zip"
    expectedChecksum="ee8fa390e3764c829dd214bff7d1fab0dbf71045"

elif [[ "$sugarName" == "Sugar$sugarEdition_Ent-$sugarVersion_7_10" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/4921-102-5-6966/SugarEnt-7.10.0.0-dev.1.zip"
    expectedChecksum="b72d1e9928840ffb9be51a2c27354a9bc3bbc5c4"

elif [[ "$sugarName" == "Sugar$sugarEdition_Pro-$sugarVersion_7_10" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/4941-102-2-6968/SugarPro-7.10.0.0-dev.1.zip"
    expectedChecksum="ad379cd8fb9960237a025e635e047c0df99096e2"

elif [[ "$sugarName" == "Sugar$sugarEdition_Ult-$sugarVersion_7_11" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/5958-102-1-8147/SugarUlt-7.11.0.0-dev.1.zip"
    expectedChecksum="46e29eff7cfffda15da65bc6d4d5ca765d129595"

elif [[ "$sugarName" == "Sugar$sugarEdition_Ent-$sugarVersion_7_11" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/5959-102-1-8148/SugarEnt-7.11.0.0-dev.1.zip"
    expectedChecksum="9446be45f8e2ea2e8e8246b76d9a32a3737c0219"

elif [[ "$sugarName" == "Sugar$sugarEdition_Pro-$sugarVersion_7_11" ]]
then
    authenticateToDevBuildsCommunity
    downloadUrl="https://community.sugarcrm.com/servlet/JiveServlet/downloadBody/5957-102-1-8146/SugarPro-7.11.0.0-dev.1.zip"
    expectedChecksum="8980d43bdf3a6af1a8d4d29396863121fa202603"

elif [[ "$sugarName" == "Sugar$sugarEdition_Ult-$sugarVersion_8_0" ]]
then
    downloadUrl="$(authenticateToSugarStoreAndGetDownloadUrl "SugarUlt-8.0.0.0.zip")"
    #TODO: Add checksum once 8.0 is GA. Issue #55
    expectedChecksum=""

elif [[ "$sugarName" == "Sugar$sugarEdition_Ent-$sugarVersion_8_0" ]]
then
    downloadUrl="$(authenticateToSugarStoreAndGetDownloadUrl "SugarEnt-8.0.0.0.zip")"
    #TODO: Add checksum once 8.0 is GA. Issue #55
    expectedChecksum=""

elif [[ "$sugarName" == "Sugar$sugarEdition_Pro-$sugarVersion_8_0" ]]
then
    downloadUrl="$(authenticateToSugarStoreAndGetDownloadUrl "SugarPro-8.0.0.0.zip")"
    #TODO: Add checksum once 8.0 is GA. Issue #55
    expectedChecksum=""

else
    echo "Unable to find Sugar download URL for $sugarName"
    exit 1
fi


######################################################################
# Download Sugar
######################################################################

echo "Beginning download of $sugarName from $downloadUrl"
response="$(curl -v -L -c ./mycookie -b ./mycookie -o $sugarName.zip $downloadUrl 2>&1)"
checkStatusCode "200" "$response"
echo "Download complete"

#Verify the checksum is correct
checksumOutput="$(sha1sum $sugarName.zip)"
checksumOutput=($checksumOutput)
checksumOfDownload=${checksumOutput[0]}

if [[ $expectedChecksum != $checksumOfDownload ]]
then
    echo "The checksum of the downloaded file did not match the expected checksum"
    echo "Expected: $expectedChecksum"
    echo "Actual:   $checksumOfDownload"
    exit 1
fi


######################################################################
# Cleanup
######################################################################

# Delete the cookie jar file
rm $cookieFile
