#!/usr/bin/env bash
ProfileName=$1

set -e
source functions.sh

set-aws-sso-credentials $ProfileName
ScriptPath="./deploy-cfn-stack.sh"

StackName="aws-organizations-api"
TemplatePath="./cloudformation/template.yml"

Parameters="$StackName $TemplatePath"
execute_script_with_credentials $ProfileName "$ScriptPath" "$Parameters"

# API Gateway deployment to prod stage
StageName=prod
ApiId=$(aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs[?OutputKey=='ApiId'].OutputValue" --output text)
ApiStageName=$(aws cloudformation describe-stacks --stack-name $StackName --query "Stacks[0].Outputs[?OutputKey=='ApiStageName'].OutputValue" --output text)
echo "Deploying to ${StageName} stage in API Gateway ${ApiId}"
aws apigateway create-deployment --rest-api-id $ApiId --stage-name $StageName

