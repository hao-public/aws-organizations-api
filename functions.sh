function addCfnParameterFile() {
	local ParameterKey=$1
	local ParameterValue=$2
	local InputFilePath=$3

	local TempFile=`mktemp`

	jq -s --arg key "${ParameterKey}" --arg value "${ParameterValue}" '.[0] + [{"ParameterKey": $key, "ParameterValue": $value}]' "${InputFilePath}" > "${TempFile}"
	mv "${TempFile}" "${InputFilePath}"
}

function createRegionBucket() {
	local BucketName=$1
	local Region=$2
	
	if aws --region $Region s3 ls "s3://$BucketName" 2>&1 | grep -q 'NoSuchBucket'
	then
    	aws --region $Region s3 mb "s3://$BucketName"
  else
    echo Bucket already exists!
	fi

	# Secure the artifact bucket
	aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled
	aws s3api put-bucket-acl --acl private --bucket $BucketName
	aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  aws s3api put-bucket-encryption --bucket $BucketName --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
}

function check_aws_cli() {
    # Check if aws cli v2 is installed
    local RequiredVersion='aws-cli/2'
    local DownloadUrl='https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html'
    local Version=$(aws --version)

    if ! "$Version" 2>&1 | grep -q "$RequiredVersion"; then 
        echo "ERROR: You need to install $RequiredVersion to use this script!"
        echo $DownloadUrl
        exit 1
    else
        echo "AWS CLI version detected: $Version"
    fi
}

function create_new_sso_profile() {
    local ProfileName=$1
    local KeyCoreUrl='https://keycore.awsapps.com/start'
    local KeyCoreTestUrl='https://keycore-test.awsapps.com/start'

    echo "Select SSO environment to use"
    echo "1) KeyCore"
    echo "2) KeyCore Test"

    read n
    clear
    
    case $n in
    1) SSOStartUrl=$KeyCoreUrl;;
    2) SSOStartUrl=$KeyCoreTestUrl;;
    *) exit 1;;
    esac

    echo "Create a profile using the aws configure sso - for example:"
    echo "SSO start URL [None]:$SSOStartUrl"
    echo "SSO Region [None]: eu-west-1"
    echo
    aws configure sso --profile $ProfileName
}

function execute_script_with_credentials() {
  ORANGE='\033[0;33m'
  NC='\033[0m' # No Color
  
  local ProfileName=$1
  local ScriptPath=$2
  local Parameters=$3

  # Unset any keys set in environment and set default AWS_PROFILE to credential
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  export AWS_PROFILE=$ProfileName

  # # Check if any existing session credentials exist for the profile
  # if aws sts get-caller-identity 2>&1 | grep -q 'The SSO session associated with this profile has expired or is otherwise invalid'
  # then
  # 		echo "Attempting to login to AWS SSO using $ProfileName..."
  # 		aws sso login --profile $ProfileName 
  # else
  echo 
  echo "Using existing credential:"
  aws sts get-caller-identity --profile $ProfileName
  Account=$(aws iam list-account-aliases --output text --query 'AccountAliases[0]')
  if [ "$Account" == "None" ]; then
    Account=$(aws sts get-caller-identity --profile $ProfileName --output text --query 'Account' 2>&1 | tr -d '\r\n')
  fi

  # Deploy to account
  while true; do
      printf "Deploying to AWS account ${ORANGE}${Account}${NC} using the above AWS credential..\n"
      read -p "Continue? (y/n): " yn
      case $yn in
          [Yy]* ) "$ScriptPath" $Parameters; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes(y) or no(n).";;
      esac
  done
  #fi
}

function get_sts_get_caller_identity_response() {
    set +e
    local GetCallerIdentityResponse=$(aws sts get-caller-identity --profile $ProfileName 2>&1 | tr -d '\r\n' ) # strip /r/n from the variable
    set -e
    echo "$GetCallerIdentityResponse"
}

function set-aws-sso-credentials() {
  check_aws_cli

  local ProfileName=$1

  if test -z "$ProfileName"; then
      echo
      echo Error: You must enter supply a ProfileName as an argument. 
      echo example: set-aws-sso-credentials my-sso-profile-name
      echo
      echo If the profile does not already exist, a new AWS SSO profile will be created with the supplied profilename.
      echo
      echo The following profiles exist on this machine:
      echo
      echo "$(aws configure list-profiles)"
      exit 1
  fi
  
  Response=$(get_sts_get_caller_identity_response )

  case "$Response" in
    'The SSO session associated with this profile has expired or is otherwise invalid. To refresh this SSO session run aws sso login with the corresponding profile.' )
      echo "$Response"
      read -n 1 -s -r -p "Press any key to sign in to AWS SSO with the profile $ProfileName"
      aws sso login --profile $ProfileName
      ;;
    
    'Error loading SSO Token: The SSO access token has either expired or is otherwise invalid.' )
      echo "$Response"
      read -n 1 -s -r -p "Press any key to sign in to AWS SSO with the profile $ProfileName"
      aws sso login --profile $ProfileName
      ;;

    "The config profile ($ProfileName) could not be found" )
      echo "$Response"
      create_new_sso_profile $ProfileName;;

    *)
      echo "Found existing session credential for $ProfileName"
      ;;
  esac
}

function updateCfnParameterFile() {
	local ParameterKey=$1
	local ParameterValue=$2
	local InputFilePath=$3

	local TempFile=`mktemp`

	jq --arg key "${ParameterKey}" --arg value "${ParameterValue}" '. |= map( if .ParameterKey == $key then .ParameterValue = $value else . end )' "${InputFilePath}" > "${TempFile}"
	mv "${TempFile}" "${InputFilePath}"
}