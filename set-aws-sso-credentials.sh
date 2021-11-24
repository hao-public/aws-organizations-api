#!/usr/bin/env bash
ProfileName=$1

set -e
source functions.sh

set-aws-sso-credentials $ProfileName