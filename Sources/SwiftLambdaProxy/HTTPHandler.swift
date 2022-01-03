//
//  HTTPHandler.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import Logging
import AWSLambdaEvents


/// HTTPHandler-specific errors.
enum HTTPHandlerError : Error, LocalizedError
{
    case requestDebugEncodingError
    case responseDebugDecodingError
    case requestMissingUrl
    case noSuccessfulHttpUrlResponse(statusCode: Int)
    
    var localizedDescription: String {
        switch(self) {
        case .requestMissingUrl:
            return "A well-formed URL can not be formed from the HTTP request."
        case .requestDebugEncodingError:
            return "Failed to encode request JSON for debug logging."
        case .responseDebugDecodingError:
            return "Failed to decode response JSON for debug logging."
        case .noSuccessfulHttpUrlResponse(let statusCode):
            return "Received status code \(statusCode) from downstream."
        }
    }
}

extension Logger
{
    func fatalChannelError(_ message: String, channel: Channel)
    {
        self.error(Message(stringLiteral: message), metadata: nil)
        _ = channel.close()
    }
}

/// HTTP request handler (responsible for sending requests downstream and converting received responses).
@available(macOS 12.0, *)
class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    let logger = Logger(label: String(reflecting: HTTPHandler.self))
    
    var head: HTTPRequestHead? = nil
    var body: ByteBuffer? = nil
    
    let options: ProxyOptions
    
    init(options: ProxyOptions) {
        self.options = options
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            self.head = head
        case .body(let bodyBytes):
            self.body = bodyBytes
        case .end(let endHeaders):
            guard let head = self.head else {
                self.logger.fatalChannelError("Missing request parts.", channel: context.channel)
                return
            }
            
            do {
                switch(self.options.apiType) {
                case .http:
                    try self.processHttpApi(context, head, body, endHeaders)
                case .rest:
                    try self.processRestApi(context, head, body, endHeaders)
                }
            } catch {
                self.logger.fatalChannelError(error.localizedDescription, channel: context.channel)
            }
        }
    }
    
    fileprivate func processHttpApi(
        _ context: ChannelHandlerContext,
        _ head: HTTPRequestHead,
        _ body: ByteBuffer?,
        _ endHeaders: NIOHTTP1.HTTPHeaders?) throws {
        
        try self.processRequest_http(head, body, endHeaders) { (resp, error) in
            
            context.eventLoop.execute {
                let channel = context.channel
                
                guard error == nil, let resp = resp else {
                    if let handlerError = error as? HTTPHandlerError {
                        self.logger.fatalChannelError("Couldn't process request: \(handlerError.localizedDescription)", channel: channel)
                    } else if let error = error {
                        self.logger.fatalChannelError("Couldn't process request: \(error.localizedDescription)", channel: channel)
                    } else {
                        self.logger.fatalChannelError("No response and no error received.", channel: channel)
                    }
                    return
                }
                
                guard resp.isBase64Encoded != true else {
                    self.logger.fatalChannelError("Can't handle Base64 response", channel: channel)
                    return
                }
                
                var respHead = HTTPResponseHead(version: head.version,
                                                status: HTTPResponseStatus(statusCode: Int(resp.statusCode.code)))
                
                for headerKvp in (resp.headers ?? [:]) {
                    respHead.headers.add(name: headerKvp.key, value: headerKvp.value)
                }
                self.logger.debug("Parsed response headers: \(respHead.headers)")
                
                let part = HTTPServerResponsePart.head(respHead)
                _ = channel.write(part)
                
                if let bodyStr = resp.body {
                    guard let bodyData = bodyStr.data(using: .utf8) else {
                        self.logger.fatalChannelError("Failed to convert body string to data", channel: channel)
                        return
                    }
                    let bodyBuffer = ByteBuffer(data: bodyData)
                    
                    let bodypart = HTTPServerResponsePart.body(.byteBuffer(bodyBuffer))
                    _ = channel.write(bodypart)
                }
                
                let endpart = HTTPServerResponsePart.end(nil)
                _ = channel.writeAndFlush(endpart).flatMap {
                    channel.close()
                }
            }
        }
    }
    
    fileprivate func processRestApi(
        _ context: ChannelHandlerContext,
        _ head: HTTPRequestHead,
        _ body: ByteBuffer?,
        _ endHeaders: NIOHTTP1.HTTPHeaders?) throws {
        
        try self.processRequest_rest(head, body, endHeaders) { (resp, error) in
            
            context.eventLoop.execute {
                let channel = context.channel
                
                guard error == nil, let resp = resp else {
                    if let handlerError = error as? HTTPHandlerError {
                        self.logger.fatalChannelError("Couldn't process request: \(handlerError.localizedDescription)", channel: channel)
                    } else if let error = error {
                        self.logger.fatalChannelError("Couldn't process request: \(error.localizedDescription)", channel: channel)
                    } else {
                        self.logger.fatalChannelError("No response and no error received.", channel: channel)
                    }
                    return
                }
                
                guard resp.isBase64Encoded != true else {
                    self.logger.fatalChannelError("Can't handle Base64 response", channel: channel)
                    return
                }
                
                var respHead = HTTPResponseHead(version: head.version,
                                                status: HTTPResponseStatus(statusCode: Int(resp.statusCode.code)))
                
                for headerKvp in (resp.headers ?? [:]) {
                    respHead.headers.add(name: headerKvp.key, value: headerKvp.value)
                }
                self.logger.debug("Parsed response headers: \(respHead.headers)")
                
                let part = HTTPServerResponsePart.head(respHead)
                _ = channel.write(part)
                
                if let bodyStr = resp.body {
                    guard let bodyData = bodyStr.data(using: .utf8) else {
                        self.logger.fatalChannelError("Failed to convert body string to data", channel: channel)
                        return
                    }
                    let bodyBuffer = ByteBuffer(data: bodyData)
                    
                    let bodypart = HTTPServerResponsePart.body(.byteBuffer(bodyBuffer))
                    _ = channel.write(bodypart)
                }
                
                let endpart = HTTPServerResponsePart.end(nil)
                _ = channel.writeAndFlush(endpart).flatMap {
                    channel.close()
                }
            }
        }
    }
    
    fileprivate func processRequest_http(_ head: HTTPRequestHead, _ body: ByteBuffer?, _ endHeaders: NIOHTTP1.HTTPHeaders?, callback: @escaping (APIGateway.V2.Response?, Error?)->()) throws {
        
        let method = head.method.rawValue
        
        guard let headUri = URL(string: head.uri) else {
            callback(nil, HTTPHandlerError.requestMissingUrl)
            return
        }
        
        let bodyString: String?
        if let body = body {
            let bodyStringData = Data(buffer: body)
            bodyString = String(data: bodyStringData, encoding: .utf8)
        } else {
            bodyString = nil
        }
        
        let queryParams: [String:String]? = URLComponents(url: headUri, resolvingAgainstBaseURL: false)?.queryItems?.reduce([String:String]()) {
            
            res, item in res.merging(
                [item.name : (item.value ?? "") ],
                uniquingKeysWith: {_,new in new}
            )
        }
        
        let mappedHeaders: [String:String]? = head.headers.reduce(into: [String:String]()) { partialResult, newElement in
            partialResult[newElement.name] = newElement.value
        }
        
        let gatewayRequest = V2Request(
            version: "2.0",
            routeKey: "\(method) \(headUri.path)",
            rawPath: headUri.path,
            rawQueryString: headUri.query ?? "",
            cookies: nil,
            headers: mappedHeaders ?? [:],
            queryStringParameters: queryParams ?? [:],
            pathParameters: [:],
            context: V2Request.Context(
                accountId: "",
                apiId: "",
                domainName: "example.com",
                domainPrefix: "",
                stage: "",
                requestId: String(describing: UUID()),
                http: V2Request.Context.HTTP(
                    method: HTTPMethod(rawValue: method)!,
                    path: headUri.path,
                    protocol: "HTTP/1.1",
                    sourceIp: "127.0.0.1",
                    userAgent: ""),
                authorizer: nil,
                time: "",
                timeEpoch: 0),
            stageVariables: nil,
            body: bodyString,
            isBase64Encoded: false)
            
        let jsonData = try JSONEncoder().encode(gatewayRequest)
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            callback(nil, HTTPHandlerError.requestDebugEncodingError)
            return
        }
        
        self.logger.debug("Sending request downstream: \(jsonString)")
        
        Task {
            do {
                let url = self.options.getLambdaUrl()
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.httpBody = jsonData
                
                logger.info("Sending request downstream.", metadata: ["url": .stringConvertible(url.absoluteString)])
                let (data, resp) = try await URLSession.shared.data(for: req)
                
                let httpResp = resp as! HTTPURLResponse
                
                guard httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
                    callback(nil, HTTPHandlerError.noSuccessfulHttpUrlResponse(statusCode: httpResp.statusCode))
                    return
                }
                
                guard let respString = String(data: data, encoding: .utf8) else {
                    callback(nil, HTTPHandlerError.responseDebugDecodingError)
                    return
                }
                self.logger.debug("Received response from downstream: \(respString)")
                
                let respStruct = try JSONDecoder().decode(APIGateway.V2.Response.self, from: ByteBuffer(data: data))
                
                callback(respStruct, nil)
            } catch {
                callback(nil, error)
            }
        }
    }
    
    fileprivate func processRequest_rest(_ head: HTTPRequestHead, _ body: ByteBuffer?, _ endHeaders: NIOHTTP1.HTTPHeaders?, callback: @escaping (APIGateway.Response?, Error?)->()) throws {
        
        let method = head.method.rawValue
        
        guard let headUri = URL(string: head.uri) else {
            callback(nil, HTTPHandlerError.requestMissingUrl)
            return
        }
        
        let bodyString: String?
        if let body = body {
            let bodyStringData = Data(buffer: body)
            bodyString = String(data: bodyStringData, encoding: .utf8)
        } else {
            bodyString = nil
        }
        
        let queryParams: [String:String]? = URLComponents(url: headUri, resolvingAgainstBaseURL: false)?.queryItems?.reduce([String:String]()) {
            
            res, item in res.merging(
                [item.name : (item.value ?? "") ],
                uniquingKeysWith: {_,new in new}
            )
        }
        
        let mappedHeaders: [String:String]? = head.headers.reduce(into: [String:String]()) { partialResult, newElement in
            partialResult[newElement.name] = newElement.value
        }
        
        let gatewayRequest = V1Request(
            resource: "ANY",
            path: headUri.path,
            httpMethod: AWSLambdaEvents.HTTPMethod(rawValue: method)!,
            queryStringParameters: queryParams ?? [:],
            multiValueQueryStringParameters: nil,
            headers: mappedHeaders ?? [:],
            multiValueHeaders: [:],
            pathParameters: [:],
            stageVariables: [:],
            requestContext: V1Request.Context(
                resourceId: "",
                apiId: "",
                resourcePath: headUri.path,
                httpMethod: method,
                requestId: String(describing: UUID()),
                accountId: "",
                stage: "",
                identity: V1Request.Context.Identity(
                    cognitoIdentityPoolId: nil,
                    apiKey: nil,
                    userArn: nil,
                    cognitoAuthenticationType: nil,
                    caller: nil,
                    userAgent: nil,
                    user: nil,
                    cognitoAuthenticationProvider: nil,
                    sourceIp: nil,
                    accountId: nil),
                extendedRequestId: nil,
                path: headUri.path),
            body: bodyString,
            isBase64Encoded: false)

        let jsonData = try JSONEncoder().encode(gatewayRequest)
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            callback(nil, HTTPHandlerError.requestDebugEncodingError)
            return
        }
        
        self.logger.debug("Sending request downstream: \(jsonString)")
        
        Task {
            do {
                let url = self.options.getLambdaUrl()
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.httpBody = jsonData
                
                logger.info("Sending request downstream.", metadata: ["url": .stringConvertible(url.absoluteString)])
                let (data, resp) = try await URLSession.shared.data(for: req)
                
                let httpResp = resp as! HTTPURLResponse
                
                guard httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
                    callback(nil, HTTPHandlerError.noSuccessfulHttpUrlResponse(statusCode: httpResp.statusCode))
                    return
                }
                
                guard let respString = String(data: data, encoding: .utf8) else {
                    callback(nil, HTTPHandlerError.responseDebugDecodingError)
                    return
                }
                self.logger.debug("Received response from downstream: \(respString)")
                
                let respStruct = try JSONDecoder().decode(APIGateway.Response.self, from: ByteBuffer(data: data))
                
                callback(respStruct, nil)
            } catch {
                callback(nil, error)
            }
        }
    }
}
