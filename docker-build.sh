#!/bin/bash

# this program will read a list of gradle versions from a build config
# file.  For each version it will determine if a version already exists on 
# docker hub for that version.  If it does it skips that version and 
# only builds versions that do not already exist on docker hub.

# this script will build both the Oracle and openJDK versions in order for 
# us to validate that both versions pass our tests.

# A FORCE env var can be set to 1 (one) in order to force the building of 
# all versions of gradle regardless if they already exist on dockerhub.
# This is useful to ensure the docker image has the newest JDK version
# since currently only the major version (8) is specified for JDK and the
# script will get what ever the latest version 8 of JDK exists at time of build

# force build flag
FORCE=${FORCE:-0}

# init vars
config_file="build-list.cfg"
config_ok=0

# flag to determine if new docker image should be built
build_oracle=0
build_openjdk=0

# Generic error outputting function
errorout() {
   if [ $1 -ne 0 ];
        then
        echo "${2}"
        exit $1
    fi
}

if [ -f "${config_file}" ]
then
  # check if any valid entries in config file
  # valid entries have a valid alphanumeric valut in first column
  if  egrep -q "^[a-zA-Z0-9]+" ${config_file}
  then
     config_ok=1
  else
     errorout 1 "No valid entries in config file: ${config_file}"
  fi
else
   errorout 1 "Missing build list config file: ${config_file}"
fi

egrep "^[a-zA-Z0-9]+" ${config_file} | while read version rest
do
  # ensure Dockerfile does not exist
  rm -f Dockerfile

  # initialize flag for this version based on FORCE_BUILD value
  build_openjdk=${FORCE}
  build_oracle=${FORCE}

  # do not both checking if docker image exists if we are forcing a build
  if [ "${FORCE}" = 0 ]
  then

    # see if version exists on docker hub
    docker pull broadinstitute/gradle:oracle-${version}
    retcode=$?

    if [ "${retcode}" -ne "0" ]
    then
       set build_oracle=1
    fi

    # see if version exists on docker hub
    docker pull broadinstitute/gradle:openjdk-${version}
    retcode=$?

    if [ "${retcode}" -ne "0" ]
    then
       set build_openjdk=1
    fi

  fi

  if [ "${build_oracle}" = "1" ]
  then
    # create Dockerfile from template
    sed -e "s;GRADLE_NUMBER;${version};" < Dockerfile.oracle > Dockerfile

    # add some Jenkins labels to designate this build
    echo "LABEL GIT_BRANCH=${GIT_BRANCH}" >> Dockerfile
    echo "LABEL GIT_COMMIT=${GIT_COMMIT}" >> Dockerfile
    echo "LABEL BUILD_URL=${BUILD_URL}" >> Dockerfile

    docker build -t broadinstitute/gradle:oracle-${version} .
    retcode=$?
    errorout $retcode "ERROR: Build failed!"

    docker tag broadinstitute/gradle:oracle-${version} broadinstitute/gradle:oracle-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $retcode "Build successful but could not tag to build number"

    docker push broadinstitute/gradle:oracle-${version}
    echo "Pushing images to dockerhub"
    retcode=$?
    errorout $retcode "Pushing new image to docker hub"

    docker push broadinstitute/gradle:oracle-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $retcode "Pushing build_number tag image to docker hub"

    # clean up all built and pulled images
  
    cleancode=0
    echo "Cleaning up pulled and built images"
    docker rmi broadinstitute/gradle:oracle-${version}
    retcode=$?
    cleancode=$(($cleancode + $retcode))
    docker rmi broadinstitute/oracle-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $cleancode "Some images were not able to be cleaned up"
  fi

  if [ "${build_openjdk}" = "1" ]
  then
    # create Dockerfile from template
    sed -e "s;GRADLE_NUMBER;${version};" < Dockerfile.openjdk > Dockerfile

    # add some Jenkins labels to designate this build
    echo "LABEL GIT_BRANCH=${GIT_BRANCH}" >> Dockerfile
    echo "LABEL GIT_COMMIT=${GIT_COMMIT}" >> Dockerfile
    echo "LABEL BUILD_URL=${BUILD_URL}" >> Dockerfile

    docker build -t broadinstitute/gradle:openjdk-${version} .
    retcode=$?
    errorout $retcode "ERROR: Build failed!"

    docker tag broadinstitute/gradle:openjdk-${version} broadinstitute/gradle:openjdk-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $retcode "Build successful but could not tag to build number"

    docker push broadinstitute/gradle:openjdk-${version}
    echo "Pushing images to dockerhub"
    retcode=$?
    errorout $retcode "Pushing new image to docker hub"

    docker push broadinstitute/gradle:openjdk-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $retcode "Pushing build_number tag image to docker hub"
    # clean up all built and pulled images

    cleancode=0
    echo "Cleaning up pulled and built images"
    docker rmi broadinstitute/gradle:openjdk-${version}
    retcode=$?
    cleancode=$(($cleancode + $retcode))
    docker rmi broadinstitute/openjdk-${version}_${BUILD_NUMBER}
    retcode=$?
    errorout $cleancode "Some images were not able to be cleaned up"
  fi

done

test -f Dockerfile && rm -f Dockerfile

exit 0
