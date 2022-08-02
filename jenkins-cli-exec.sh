#!/bin/bash

JENKINS_URL="http://192.168.66.100:8080/"
java -jar jenkins-cli.jar -s $JENKINS_URL -auth admin:11d1e0facdd8d7fa318a73a7aaf4585dd2 "$@"
