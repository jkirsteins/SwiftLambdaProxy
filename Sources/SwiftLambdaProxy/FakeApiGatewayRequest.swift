//
//  FakeApiGatewayRequest.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation

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
struct FakeApiGatewayRequest : Codable
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
    let version: String // e.g. "2.0"
    let rawPath: String // e.g. "/todomvc"
    let body: String? // e.g. "{\"id\": 1, \"title\": \"Hello World 2\", \"completed\": false}"
    let requestContext: RequestContext
    var isBase64Encoded: Bool
    let rawQueryString: String // e.g. "query1=value1"
    let queryStringParameters: [String: String]
    let headers: [String: String]
}


