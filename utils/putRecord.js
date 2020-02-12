const AWS = require('aws-sdk');
const kinesisConstant = require('./kinesisConstants'); //Keep it consistent

const firehose = new AWS.Firehose({
  apiVersion: kinesisConstant.API_VERSION,
  endpoint: kinesisConstant.ENDPOINT,
  region: kinesisConstant.REGION
});

const readline = require('readline');
const fs = require('fs');

const readInterface = readline.createInterface({
    input: fs.createReadStream('apache.log'),
    output: process.stdout,
    console: false
});

function putRecord(payload) {
  var params = {
  DeliveryStreamName: kinesisConstant.STREAM_NAME,
  Record: {
    Data: payload
  }
  };
  firehose.putRecord(params, function(err, data) {
    if (err) console.log(err, err.stack); // an error occurred
    else     console.log(data);           // successful response
  });
}

readInterface.on('line', function(line) {
    putRecord(line);
});