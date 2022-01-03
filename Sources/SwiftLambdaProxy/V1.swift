//
//  FakeApiGatewayResponse.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import AWSLambdaEvents

public struct V1Request: Codable {
    internal init(resource: String, path: String, httpMethod: HTTPMethod, queryStringParameters: [String : String]?, multiValueQueryStringParameters: [String : [String]]?, headers: HTTPHeaders, multiValueHeaders: HTTPMultiValueHeaders, pathParameters: [String : String]?, stageVariables: [String : String]?, requestContext: V1Request.Context, body: String?, isBase64Encoded: Bool) {
        self.resource = resource
        self.path = path
        self.httpMethod = httpMethod
        self.queryStringParameters = queryStringParameters
        self.multiValueQueryStringParameters = multiValueQueryStringParameters
        self.headers = headers
        self.multiValueHeaders = multiValueHeaders
        self.pathParameters = pathParameters
        self.stageVariables = stageVariables
        self.requestContext = requestContext
        self.body = body
        self.isBase64Encoded = isBase64Encoded
    }
    
    
    
    public struct Context: Codable {
        internal init(resourceId: String, apiId: String, resourcePath: String, httpMethod: String, requestId: String, accountId: String, stage: String, identity: V1Request.Context.Identity, extendedRequestId: String?, path: String) {
            self.resourceId = resourceId
            self.apiId = apiId
            self.resourcePath = resourcePath
            self.httpMethod = httpMethod
            self.requestId = requestId
            self.accountId = accountId
            self.stage = stage
            self.identity = identity
            self.extendedRequestId = extendedRequestId
            self.path = path
        }
        
        public struct Identity: Codable {
            internal init(cognitoIdentityPoolId: String?, apiKey: String?, userArn: String?, cognitoAuthenticationType: String?, caller: String?, userAgent: String?, user: String?, cognitoAuthenticationProvider: String?, sourceIp: String?, accountId: String?) {
                self.cognitoIdentityPoolId = cognitoIdentityPoolId
                self.apiKey = apiKey
                self.userArn = userArn
                self.cognitoAuthenticationType = cognitoAuthenticationType
                self.caller = caller
                self.userAgent = userAgent
                self.user = user
                self.cognitoAuthenticationProvider = cognitoAuthenticationProvider
                self.sourceIp = sourceIp
                self.accountId = accountId
            }
            
            public let cognitoIdentityPoolId: String?

            public let apiKey: String?
            public let userArn: String?
            public let cognitoAuthenticationType: String?
            public let caller: String?
            public let userAgent: String?
            public let user: String?

            public let cognitoAuthenticationProvider: String?
            public let sourceIp: String?
            public let accountId: String?
        }

        public let resourceId: String
        public let apiId: String
        public let resourcePath: String
        public let httpMethod: String
        public let requestId: String
        public let accountId: String
        public let stage: String

        public let identity: Identity
        public let extendedRequestId: String?
        public let path: String
    }

    public let resource: String
    public let path: String
    public let httpMethod: HTTPMethod

    public let queryStringParameters: [String: String]?
    public let multiValueQueryStringParameters: [String: [String]]?
    public let headers: HTTPHeaders
    public let multiValueHeaders: HTTPMultiValueHeaders
    public let pathParameters: [String: String]?
    public let stageVariables: [String: String]?

    public let requestContext: Context
    public let body: String?
    public let isBase64Encoded: Bool
}

public struct V1Response: Codable {
    public var statusCode: HTTPResponseStatus
    public var headers: HTTPHeaders?
    public var multiValueHeaders: HTTPMultiValueHeaders?
    public var body: String?
    public var isBase64Encoded: Bool?

    public init(
        statusCode: HTTPResponseStatus,
        headers: HTTPHeaders? = nil,
        multiValueHeaders: HTTPMultiValueHeaders? = nil,
        body: String? = nil,
        isBase64Encoded: Bool? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.multiValueHeaders = multiValueHeaders
        self.body = body
        self.isBase64Encoded = isBase64Encoded
    }
}
