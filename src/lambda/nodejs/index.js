class LambdaCacheController {
  constructor() {
    this.value = null;
    this.timestamp = null;
    this.ttl = 300000; // default 5 minutes
  }

  async getValue() {
    return new Promise((resolve, reject) => {
      try {
        const { timestamp, value, ttl } = this;
        const expiresIn = timestamp + ttl - Date.now();

        resolve(
          value && timestamp && expiresIn > 0
            ? {
                value: JSON.parse(value),
                expiresIn,
              }
            : null
        );
      } catch (e) {
        console.error(e);
        reject(e);
      }
    });
  }

  async setValue(valueToCache, timeToLive) {
    return new Promise((resolve, reject) => {
      try {
        this.value = JSON.stringify(valueToCache);
        this.timestamp = Date.now();
        if (timeToLive) this.ttl = timeToLive;

        resolve(true);
      } catch (e) {
        console.error(e);
        reject(e);
      }
    });
  }
}

const AWS = require('aws-sdk');
const roleArn = process.env.ROLE_ARN;
const roleSessionName = process.env.ROLE_SESSION_NAME;
const externalId = process.env.EXTERNAL_ID;
const secretArn = process.env.SECRET_TOKEN_ARN

// save the original lambda running credentials so we can restore them in case of any errors
const origCredentials = AWS.config.credentials;

// create cache controller for secret token in the global scope
const secretCache = new LambdaCacheController();

exports.handler = async (event) => {
  try {

    console.log('Received event:', JSON.stringify(event, null, 2));

    // get token from event headers
    let headers = event.headers
    let token = headers['X-API-Key'];
    if (token == undefined) {
      throw new Error('Token is undefined');
    }
    
    // try and get secret from the cache controller
    let secretCacheData = await secretCache.getValue();
    
    if (!secretCacheData) {
      console.log('Secret token not found in cache. Fetching it from Secrets Manager...')
      // get the secret token from Secrets Manager
      let secret = JSON.parse(await getSecret(secretArn));
      let secretToken = secret.token;
      
      // save the secret token to the cache controller
      await secretCache.setValue(secretToken);
          
      secretCacheData = await secretCache.getValue();
    } else {
      console.log('Secret token found in cache with expiration in ' + Math.round(secretCacheData.expiresIn/1000) + ' seconds');
    }
    
    let secretToken = secretCacheData.value;
    console.log(secretToken);

    // check if the token in the event body matches the secret token from Secrets Manager
    if (token != secretToken) {
      throw new Error('Token does not match secret');
    }

    // get the api action from the event operationName 
    let action = event.requestContext.operationName;
    if (action == undefined) {
      throw new Error('Missing operationName in event');
    } else {
      console.log('operationName received from event: ' + action);
    }
  
    // set params to empty array if event.parameters is undefined
    let params = event.pathParameters;
    if (params == undefined) {
      console.log('Event contains no path parameters');
      params = {};
    } else {
      console.log('pathParameters: ' + JSON.stringify(params, null, 2));
    }
  
    // get cross account assumerole credentials 
    const credentials = await getCredentials(roleArn, roleSessionName, externalId);
    
    // get response body from the Organizations API call
    const responseBody = await organizationsApi(credentials, action, params);
    
    // successful response from the API call does not contain any statusCode - so set it to 200
    if (responseBody.statusCode == undefined) {
      const response = formatResponse(200, responseBody);
      return response;
    // treat all other responses as errors
    } else {
      throw new Error(responseBody);
    }
  }
  catch (err) {
    // set lambda credentials back to the original if an error occurs
    AWS.config.credentials = origCredentials;
    
    // log the error
    console.error(err);
    
    // don't reveal the nature of errors to outside callers for security reasons
    // return default error response as 'Internal Server Error' with statuscode 500
    if (err.statusCode) {
      return formatResponse(err.statusCode, err.message );
    } else {
    return formatResponse(500, 'Internal Server Error')
    }
  }

};


// -----------------------------------------------------------------------------

function formatResponse(statusCode, body) {
  return {
    statusCode: statusCode,
    headers: {
      "Content-Type" : "application/json"
    },
    body: JSON.stringify(body),
    isBase64Encoded: false
  };
}

async function getCredentials(roleArn, roleSessionName, externalId) {
  var sts = new AWS.STS({region: process.env.AWS_REGION});
  let sts_params= {
      RoleArn: roleArn, 
      DurationSeconds: 900, 
      RoleSessionName: roleSessionName,
      ExternalId: externalId
  };
  console.log('Trying to assume role: ' + roleArn);
  try {
      const response = await sts.assumeRole(sts_params).promise();
      console.log('AssumedRoleUserArn: ' + response.AssumedRoleUser.Arn);
      let credentials = new AWS.Credentials({
          accessKeyId: response.Credentials.AccessKeyId, secretAccessKey: response.Credentials.SecretAccessKey, sessionToken: response.Credentials.SessionToken
      });
  return credentials;
  }
  catch (err) {
      console.log(err);
      throw new Error('Error assuming role');
  }
}

async function getSecret(secretArn){
  var secrets_manager = new AWS.SecretsManager({region: process.env.AWS_REGION});

  let secrets_manager_params = {
    SecretId: secretArn
  };
  
  try {
    console.log('Retrieving secret from: ' + secretArn);
    const response = await secrets_manager.getSecretValue(secrets_manager_params).promise();
    return response.SecretString;
  }
  catch (err) {
    console.log(err);
    throw new Error('Error retrieving secret');
  }
}

function getApiMap(action) {
  const apiMap = {
    DescribeAccount: {
      DataArrayName: 'Account',
      MethodName: 'describeAccount'
    },
    DescribeOrganizationalUnit: {
      DataArrayName: 'OrganizationalUnit',
      MethodName: 'describeOrganizationalUnit'
    },
    ListAccounts: { 
      DataArrayName: 'Accounts',
      MethodName: 'listAccounts'
    },
    ListAccountsForParent: { 
      DataArrayName: 'Accounts',
      MethodName: 'listAccountsForParent'
    },
    ListChildren: { 
      DataArrayName: 'Children',
      MethodName: 'listChildren'
    },
    ListOrganizationalUnitsForParent: { 
      DataArrayName: 'OrganizationalUnits',
      MethodName: 'listOrganizationalUnitsForParent'
    },
    ListParents: { 
      DataArrayName: 'Parents',
      MethodName: 'listParents'
    },
    ListRoots: { 
      DataArrayName: 'Roots',
      MethodName: 'listRoots'
    },
    ListTagsForResource: { 
      DataArrayName: 'Tags',
      MethodName: 'listTagsForResource'
    }
  };
  
  try {
    return apiMap[action];
  } catch (err) {
    console.error(err);
    throw Error ('Unsupported action: ' + action);
  }
}

async function organizationsApi(credentials, action, params){
  
  let apiMap = getApiMap(action);
  let dataArrayName = apiMap.DataArrayName;
  let methodName = apiMap.MethodName;
  
  const client = new AWS.Organizations({ apiVersion: '2016-11-28', credentials: credentials, region: 'us-east-1' });

  let returnData = [];
  let token = '';

  while (token != null)  {
    if (token) { params.NextToken = token }
    try { 
      const data = await client[methodName](params).promise();
      if (data.NextToken) { 
        token = data.NextToken;
      } else {
        token = null;
        if (returnData.length == 0) {
          // only a single record exists
          data.RecordCount = 1;
          return data;
        }
      }
      returnData.push(...data[dataArrayName]);
    } 
    catch (err) {
      console.log(err);
      throw Error ('Error in invoking method: ' + methodName);
    }
  }
  return { [dataArrayName]: returnData, RecordCount: returnData.length };
}
