# docker-gradle

This repo holds the build script to automate building of a docker container
for the Gradle build tool.  The build script will build both a image based on 
Oracle's JDK and OpenJDK for EACH version of gradle that is listed in the 
build-list.cfg file.  The build pushes docker image to broadinstitute/gradle

The docker tagging convention is:
   [oracle|openjdk]-<GRADLE_VERSION>

There is also a secondary tag for each version:
   [oracle|openjdk]-<GRADLE_VERSION>_<BUILD_NUMBER>

Where BUILD_NUMBER is a forever increasing numerical number.  This way if
the same version is "force" built we can still access previous version since
it will have a differnet build number.
