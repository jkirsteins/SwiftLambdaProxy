//
//  FakeApiGatewayRequest.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation
import AWSLambdaEvents

/*
 {
     "routeKey":"GET /todomvc",
     "version":"2.0",
     "rawPath":"/todomvc",
     "requestContext":{
         "accountId":"",
         "apiId":"",
         "domainName":"",
         "domainPrefix":"",
         "stage": "",
         "requestId": "",
         "http":{
             "path":"/todomvc",
             "method":"GET",
             "protocol":"HTTP/1.1",
             "sourceIp":"",
             "userAgent":""
         },
         "time": "",
         "timeEpoch":0
     },
     "isBase64Encoded":false,
     "rawQueryString":"query1=value1",
     "headers":{}
 }
 */

/// Structure mimicking API Gateway request. Not all fields are set properly.
struct FakeApiGatewayRequest_off : Codable
{
    struct RequestContext : Codable
    {
        struct Http : Codable
        {
            let path: String // e.g. "/todomvc",
            let method: String // e.g. "GET"
            let `protocol`: String // e.g. "HTTP/1.1"
            let sourceIp: String
            let userAgent: String
        }
        let accountId: String
        let apiId: String
        let domainName: String
        let domainPrefix: String
        let stage: String
        let requestId: String
        let http: Http
        let time: String
        let timeEpoch: Int
    }
    
    let routeKey: String // e.g. "GET /todomvc"
    // let version: String // e.g. "2.0"
    let rawPath: String // e.g. "/todomvc"
    let body: String? // e.g. "{\"id\": 1, \"title\": \"Hello World 2\", \"completed\": false}"
    let requestContext: RequestContext
    var isBase64Encoded: Bool
    let rawQueryString: String // e.g. "query1=value1"
    let queryStringParameters: [String: String]
    let headers: [String: String]
}

/// APIGateway.V2.Request contains data coming from the new HTTP API Gateway
public struct V2Request: Codable {
    internal init(version: String, routeKey: String, rawPath: String, rawQueryString: String, cookies: [String]?, headers: HTTPHeaders, queryStringParameters: [String : String]?, pathParameters: [String : String]?, context: V2Request.Context, stageVariables: [String : String]?, body: String?, isBase64Encoded: Bool) {
        self.version = version
        self.routeKey = routeKey
        self.rawPath = rawPath
        self.rawQueryString = rawQueryString
        self.cookies = cookies
        self.headers = headers
        self.queryStringParameters = queryStringParameters
        self.pathParameters = pathParameters
        self.context = context
        self.stageVariables = stageVariables
        self.body = body
        self.isBase64Encoded = isBase64Encoded
    }
    
    /// Context contains the information to identify the AWS account and resources invoking the Lambda function.
    public struct Context: Codable {
        internal init(accountId: String, apiId: String, domainName: String, domainPrefix: String, stage: String, requestId: String, http: V2Request.Context.HTTP, authorizer: V2Request.Context.Authorizer?, time: String, timeEpoch: UInt64) {
            self.accountId = accountId
            self.apiId = apiId
            self.domainName = domainName
            self.domainPrefix = domainPrefix
            self.stage = stage
            self.requestId = requestId
            self.http = http
            self.authorizer = authorizer
            self.time = time
            self.timeEpoch = timeEpoch
        }
        
        public struct HTTP: Codable {
            public let method: HTTPMethod
            public let path: String
            public let `protocol`: String
            public let sourceIp: String
            public let userAgent: String
        }

        /// Authorizer contains authorizer information for the request context.
        public struct Authorizer: Codable {
            internal init(jwt: V2Request.Context.Authorizer.JWT) {
                self.jwt = jwt
            }
            
            /// JWT contains JWT authorizer information for the request context.
            public struct JWT: Codable {
                public let claims: [String: String]
                public let scopes: [String]?
            }

            public let jwt: JWT
        }

        public let accountId: String
        public let apiId: String
        public let domainName: String
        public let domainPrefix: String
        public let stage: String
        public let requestId: String

        public let http: HTTP
        public let authorizer: Authorizer?

        /// The request time in format: 23/Apr/2020:11:08:18 +0000
        public let time: String
        public let timeEpoch: UInt64
    }

    public let version: String
    public let routeKey: String
    public let rawPath: String
    public let rawQueryString: String

    public let cookies: [String]?
    public let headers: HTTPHeaders
    public let queryStringParameters: [String: String]?
    public let pathParameters: [String: String]?

    public let context: Context
    public let stageVariables: [String: String]?

    public let body: String?
    public let isBase64Encoded: Bool

    enum CodingKeys: String, CodingKey {
        case version
        case routeKey
        case rawPath
        case rawQueryString

        case cookies
        case headers
        case queryStringParameters
        case pathParameters

        case context = "requestContext"
        case stageVariables

        case body
        case isBase64Encoded
    }
}

public struct V2Response: Codable {
    public var statusCode: HTTPResponseStatus
    public var headers: HTTPHeaders?
    public var body: String?
    public var isBase64Encoded: Bool?
    public var cookies: [String]?

    public init(
        statusCode: HTTPResponseStatus,
        headers: HTTPHeaders? = nil,
        body: String? = nil,
        isBase64Encoded: Bool? = nil,
        cookies: [String]? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.isBase64Encoded = isBase64Encoded
        self.cookies = cookies
    }
}



