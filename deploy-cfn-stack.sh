#!/usr/bin/env bash
StackName=$1
TemplateFilePath=$2

set -e
echo Working directory: $PWD

source functions.sh

DefaultRegion="eu-west-1"
echo Set default region to $DefaultRegion 
export AWS_DEFAULT_REGION="$DefaultRegion" 

AccountId=$(aws sts get-caller-identity --output text --query 'Account')
echo AccountId: $AccountId
AccountAlias=$(aws iam list-account-aliases --output text --query 'AccountAliases[0]')
echo AccountAlias: $AccountAlias

# Create S3 bucket for uploading packaged cfn files for deploying codepipeline templates
ArtifactBucket="cf-templates-${AccountId}-${AWS_DEFAULT_REGION}"
echo Creating regional bucket for cfn templates: $ArtifactBucket
createRegionBucket $ArtifactBucket $AWS_DEFAULT_REGION

# -----------------------------------------------------------------

# Stack parameters
Capabilities="CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM"
CfnParametersDefaultPath="./etc/config/default/parameters.json"
CfnParametersOverridePath="./etc/config/${AccountAlias}/parameters.json"
PackagedTemplateFolderPath="./build/cloudformation"
PackagedTemplateFilePath="${PackagedTemplateFolderPath}/packaged.yml"
StackRegion="eu-west-1"

CfnParametersAdd=`mktemp`
CfnParametersOverrideMerged=`mktemp`
CfnParametersDeploytime=`mktemp`

# Merge CloudFormation parameter override file with default
if [ -f "$CfnParametersOverridePath" ]; then
  echo "Found CloudFormation parameters override file"
  # Merge json files using jq
  jq -s '.[0] as $a | .[1] as $b | . = ($a + $b) | unique_by(.ParameterKey)' "$CfnParametersOverridePath" "$CfnParametersDefaultPath" > "$CfnParametersOverrideMerged"
  CfnParametersPath="$CfnParametersOverrideMerged"
else
  CfnParametersPath=$CfnParametersDefaultPath
fi

# Update CloudFormation parameter file with deploytime parameters
echo Update deploytime CloudFormation parameters... 
cp "${CfnParametersPath}" "${CfnParametersDeploytime}"
#updateCfnParameterFile ApiDefinitionBodyLocation "${OpenApiFileS3Path}" "${CfnParametersDeploytime}"

echo CloudFormation deployment parameters:
cat "${CfnParametersDeploytime}"

# Store CloudFormation parameters in variable
export CloudFormationParameters=$(cat "${CfnParametersDeploytime}")

# Cleanup .overridemerged file
if [ -f "${CfnParametersOverrideMerged}" ]; then
  rm "${CfnParametersOverrideMerged}" 
fi

# Cleanup .deploytime file
if [ -f "${CfnParametersDeploytime}" ]; then
  rm "${CfnParametersDeploytime}"
fi

# build cloudformation packages
if [ ! -d "${PackagedTemplateFolderPath}" ]; then
  mkdir -p "${PackagedTemplateFolderPath}" 
fi
echo cloudformation package start
aws cloudformation package \
  --s3-bucket $ArtifactBucket \
  --s3-prefix packaged-templates \
  --output-template "$PackagedTemplateFilePath" \
  --region $StackRegion \
  --template-file "$TemplateFilePath"
echo cloudformation package status $?	

# Stack deployment
echo cloudformation deploy start
aws cloudformation deploy \
  --capabilities $Capabilities \
  --no-fail-on-empty-changeset \
  --parameter-overrides "$CloudFormationParameters"  \
  --region $StackRegion \
  --stack-name "$StackName" \
  --template-file "$PackagedTemplateFilePath" \
  --tags "Environment=Sandbox"
echo cloudformation deploy status $?

