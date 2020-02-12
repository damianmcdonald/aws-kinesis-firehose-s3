#!/bin/bash

##############################################################
#                                                            #
# This sample demonstrates the following concepts:           #
#                                                            #
# * Creates a Kinesis Delivery Stream                        #
# * Creates an S3 Bucket as a delivery location              #
#   for the transformed data                                 #
# * Creates a Lambda function for transforming               #
#   the apache log data to csv                               #
# * IAM role creation                                        #
# * Cleans up all the resources created                      #
#                                                            #
##############################################################

# Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
DARK_GRAY='\033[1;30m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
LIGHT_PURPLE='\033[1;35m'
LIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variable declarations
PROJECT_DIR=$PWD
AWS_PROFILE=dcorp
AWS_REGION=$(aws configure get region --output text --profile ${AWS_PROFILE})
SAM_STACK_NAME=sam-apache-log-to-csv
KINESIS_STACK_NAME=kinesis-firehose-s3
KINESIS_STACK_TEMPLATE=kinesis-template.yml
SAM_STACK_TEMPLATE=sam-template.yml
# cloudformation templates to validate
CFN_TEMPLATES=($KINESIS_STACK_TEMPLATE $SAM_STACK_TEMPLATE)
CFN_LAMBDA_PREFIX=lambda-functions
CFN_RESOURCES_BUCKET=cloudformationresourcesdcorp
OUTPUT_FILE=${PROJECT_DIR}/sam-stack-output.yml
UNDEPLOY_FILE=aws-undeploy.sh

###########################################################
#                                                         #
#  Validate the CloudFormation templates                  #
#                                                         #
###########################################################
echo -e "[${LIGHT_BLUE}INFO${NC}] Validating CloudFormation templates";

for CFN_STACK in ${CFN_TEMPLATES[@]}; do
  echo -e "[${LIGHT_BLUE}INFO${NC}] Validating CloudFormation template ${YELLOW}$CFN_STACK${NC}";
  cat $CFN_STACK | xargs -0 aws cloudformation validate-template --profile ${AWS_PROFILE} --template-body
  # assign the exit code to a variable
  TEMPLATE_VALIDAION_CODE="$?"

  # check the exit code, 255 means the CloudFormation template was not valid
  if [ $TEMPLATE_VALIDAION_CODE != "0" ]; then
      echo -e "[${RED}FATAL${NC}] CloudFormation template ${YELLOW}$CFN_STACK${NC} failed validation with non zero exit code ${YELLOW}$TEMPLATE_VALIDAION_CODE${NC}. Exiting.";
      exit 999;
  fi

  echo -e "[${GREEN}SUCCESS${NC}] CloudFormation template ${YELLOW}$CFN_STACK${NC} is valid.";
done

###########################################################
#                                                         #
#  Build the SAM functions                                #
#                                                         #
###########################################################
echo -e "[${LIGHT_BLUE}INFO${NC}] building the SAM functions";
cd $PROJECT_DIR/src
npm install
# npm run-script lint
echo -e "[${LIGHT_BLUE}INFO${NC}] creating a production release";
npm prune --production

###########################################################
#                                                         #
#  Package the SAM stack                                  #
#                                                         #
###########################################################
echo -e "[${LIGHT_BLUE}INFO${NC}] packaging the SAM stack ....";
echo -e "aws cloudformation package --template-file $SAM_STACK_TEMPLATE --output-template-file $OUTPUT_FILE --s3-bucket $CFN_RESOURCES_BUCKET --s3-prefix $CFN_LAMBDA_PREFIX"
cd $PROJECT_DIR
aws cloudformation package \
  --template-file $SAM_STACK_TEMPLATE \
  --output-template-file $OUTPUT_FILE \
  --s3-bucket $CFN_RESOURCES_BUCKET \
  --s3-prefix $CFN_LAMBDA_PREFIX \
  --profile ${AWS_PROFILE}

###########################################################
#                                                         #
#  Deploy the SAM stack                                   #
#                                                         #
###########################################################
echo -e "[${LIGHT_BLUE}INFO${NC}] deploying the SAM stack ....";
echo -e "aws cloudformation deploy --template-file $OUTPUT_FILE --stack-name $SAM_STACK_NAME --capabilities CAPABILITY_IAM"
aws cloudformation deploy \
  --template-file $OUTPUT_FILE \
  --stack-name $SAM_STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --profile ${AWS_PROFILE}

###########################################################
#                                                         #
#  Execute the CloudFormation templates                   #
#                                                         #
###########################################################

echo -e "[${LIGHT_BLUE}INFO${NC}] Exectuing the Kinesis CloudFormation template ${YELLOW}$KINESIS_STACK_NAME${NC}.";
aws cloudformation create-stack \
	--template-body file://${KINESIS_STACK_TEMPLATE} \
	--stack-name ${KINESIS_STACK_NAME} \
	--capabilities CAPABILITY_IAM \
	--parameters \
	ParameterKey=SamStackName,ParameterValue=${SAM_STACK_NAME} \
	--profile ${AWS_PROFILE}

echo -e "[${LIGHT_BLUE}INFO${NC}] Waiting for the creation of SAM stack ${YELLOW}$KINESIS_STACK_NAME${NC} ....";
aws cloudformation wait stack-create-complete --stack-name $KINESIS_STACK_NAME --profile ${AWS_PROFILE}

###########################################################
#                                                         #
# Undeployment file creation                              #
#                                                         #
###########################################################

# grab the S3 Bucket Name from the stack output
S3_DELIVERY_BUCKET_DOMAIN=$(aws cloudformation describe-stacks --stack-name ${KINESIS_STACK_NAME} --profile ${AWS_PROFILE} --query "Stacks[].Outputs[?OutputKey == 'S3BucketName'][OutputValue]" --output text)
S3_DELIVERY_BUCKET_NAME=$(echo "${S3_DELIVERY_BUCKET_DOMAIN}" | sed -e "s/.s3.amazonaws.com$//")

# delete any previous instance of undeploy.sh
if [ -f "$UNDEPLOY_FILE" ]; then
    rm $UNDEPLOY_FILE
fi

cat > $UNDEPLOY_FILE <<EOF
#!/bin/bash

# Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
DARK_GRAY='\033[1;30m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
LIGHT_PURPLE='\033[1;35m'
LIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "[${LIGHT_BLUE}INFO${NC}] Delete S3 Bucket ${YELLOW}${S3_DELIVERY_BUCKET_NAME}${NC}.";
aws s3 rm s3://${S3_DELIVERY_BUCKET_NAME}/ --recursive --profile ${AWS_PROFILE}
aws s3 rb s3://${S3_DELIVERY_BUCKET_NAME} --profile ${AWS_PROFILE}

echo -e "[${LIGHT_BLUE}INFO${NC}] Terminating cloudformation stack ${YELLOW}${KINESIS_STACK_NAME}${NC} ....";
aws cloudformation delete-stack --stack-name ${KINESIS_STACK_NAME} --profile ${AWS_PROFILE}

echo -e "[${LIGHT_BLUE}INFO${NC}] Waiting for the deletion of cloudformation stack ${YELLOW}${KINESIS_STACK_NAME}${NC} ....";
aws cloudformation wait stack-delete-complete --stack-name ${KINESIS_STACK_NAME} --profile ${AWS_PROFILE}

echo -e "[${LIGHT_BLUE}INFO${NC}] Terminating cloudformation stack ${YELLOW}${SAM_STACK_NAME}${NC} ....";
aws cloudformation delete-stack --stack-name ${SAM_STACK_NAME} --profile ${AWS_PROFILE}

echo -e "[${LIGHT_BLUE}INFO${NC}] Waiting for the deletion of cloudformation stack ${YELLOW}${SAM_STACK_NAME}${NC} ....";
aws cloudformation wait stack-delete-complete --stack-name ${SAM_STACK_NAME} --profile ${AWS_PROFILE}

aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE --profile ${AWS_PROFILE}
EOF

chmod +x $UNDEPLOY_FILE