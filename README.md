# AWS Kinesis Firehose S3

The `aws-kinesis-firehose-s3` project is based on the [Serverless Application Model kinesis-firehose-apachelog-to-csv](https://github.com/aws-samples/serverless-app-examples/tree/master/javascript/kinesis-firehose-apachelog-to-csv) example provided by Amazon.

The project provides:

* Kinesis Delivery Stream which accepts entries from an apache log file
* Lambda function for transforming the apache log data to csv
* S3 Bucket as a delivery location for the transformed data
* Scripts to clean up all the resources created

# Architecture overview

The project architecture is depicted in the diagram below:

![Architecture diagram](assets/architecture.png)

# Prerequisites

* An AWS account with appropriate permissions to create the required resources
* [AWS CLI installed and configured](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html)
* [Node.js](https://nodejs.org/en/) (v12+) and [npm](https://www.npmjs.com/) (v6+) installed and [configured for use with AWS](https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/getting-started-nodejs.html)
* Bash environment in which to execute the scripts

# Deploy the project

## Grab the project 

The first step is to git clone the project.

```bash
git clone --verbose --progress https://github.com/damianmcdonald/aws-kinesis-firehouse-s3 aws-kinesis-firehouse-s3
```

## Configure global variables

The second step is to modify any of the global variables to suit your needs.

The global variables are defined in the [aws-deploy.sh](aws-deploy.sh) script.

You will need to update the `AWS_PROFILE` variable to reflect the profile that you have configured in the AWS CLI.

For the remaining global variables, if you just want to have a sandbox environment to experiment with the project then the defaults below are probably fine.

```bash
# Global variable declarations
PROJECT_DIR=$PWD
AWS_PROFILE=<!-- ADD_YOUR_AWS_CLI_PROFILE_HERE -->
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
```

## Create the resources and deploy the project

Create the resources and deploy the project by executing the [aws-deploy.sh](aws-deploy.sh) script.

```bash
./aws-deploy.sh
```

As part of the execution of the [aws-deploy.sh](aws-deploy.sh) script, an additional file is dynamically created.

Location | Purpose
------------ | -------------
aws-undeploy.sh | Script that can be used to destroy and clean-up all of the resources created by the `aws-kinesis-firehose-s3` project

# Test the Lambda Function

The project contains a [test event](test/test-event.json) that can be used to invoke the Lambda function.

For details on how to test a lambda function using a test event in the AWS Console, refer to https://docs.aws.amazon.com/lambda/latest/dg/getting-started-create-function.html.

The high level steps are:

1. Logon to AWS Console
2. Navigate to the Lambda service
3. Click the **Test** button in the upper right corner
4. In the **Configure** test event page, choose **Create new test event** and in **Event template** add the content of [test event](test/test-event.json). Enter an **Event** name and choose **Create**
5. AWS Lambda executes your function on your behalf. The handler in your Lambda function receives and then processes the sample event.
6. Upon successful execution, view results in the console.
	* The Execution result section shows the execution status as succeeded and also shows the function execution results, returned by the return statement.
	* The Summary section shows the key information reported in the Log output section (the REPORT line in the execution log).
7. The Log output section shows the log AWS Lambda generates for each execution. These are the logs written to CloudWatch by the Lambda function. The AWS Lambda console shows these logs for your convenience.

# Test the Kinesis Firehose Delivery Stream

The project contains a [Node.js Kinesis Firehose Delivery Stream Producer](utils/putRecord.js) that can be used to read a sample Apache log file and push the log lines to the Kinesis Firehose Delivery Stream.

1. Navigate to [utils](utils) folder
2. Update the [kinesisConstants.js](kinesisConstants.js) to reflect the values for your environment
3. Execute the [putRecord.js](putRecord.js) file; `node putRecord.js`
4. Check the Lambda log stream group in CloudWatch
5. Check the S3 Bucket in order verify if the converted log entries have been delivered 