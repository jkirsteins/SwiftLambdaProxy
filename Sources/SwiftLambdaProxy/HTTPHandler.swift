//
//  File.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat

@available(macOS 12.0, *)
class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
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
                fatalError("Missing request parts")
            }
            
            do {
                try self.processRequest(head, body, endHeaders) { resp in
                    
                    context.eventLoop.execute {
                        
                        guard !resp.isBase64Encoded else {
                            fatalError("Can't handle Base64 response")
                        }
                        
                        let channel = context.channel
                        var respHead = HTTPResponseHead(version: head.version,
                                                        status: HTTPResponseStatus(statusCode: resp.statusCode))
                        
                        print("--- Response headers ---")
                        for headerKvp in resp.headers {
                            print("    \(headerKvp.key): \(headerKvp.value)")
                            respHead.headers.add(name: headerKvp.key, value: headerKvp.value)
                        }
                        print("--- End response headers ---")
                        
                        let part = HTTPServerResponsePart.head(respHead)
                        _ = channel.write(part)
                        
                        if let bodyStr = resp.body {
                            guard let bodyData = bodyStr.data(using: .utf8) else {
                                fatalError("Failed to convert body string to data")
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
            } catch {
                fatalError("Error while processing request")
            }
        }
    }
    
    fileprivate func processRequest(_ head: HTTPRequestHead, _ body: ByteBuffer?, _ endHeaders: HTTPHeaders?, callback: @escaping (FakeApiGatewayResponse)->()) throws {
        
        let method = head.method.rawValue
        let headUri = URL(string: head.uri)!
        
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
            
        let gatewayRequest = FakeApiGatewayRequest(
            routeKey: "\(method) \(headUri.path)",
            version: "2.0",
            rawPath: headUri.path,
            body: bodyString,
            requestContext: FakeApiGatewayRequest.RequestContext(
                accountId: "",
                apiId: "",
                domainName: "example.com",
                domainPrefix: "",
                stage: "",
                requestId: String(describing: UUID()),
                http: FakeApiGatewayRequest.RequestContext.Http(
                    path: headUri.path,
                    method: method,
                    protocol: "HTTP/1.1",
                    sourceIp: "",
                    userAgent: ""),
                time: "",
                timeEpoch: 0),
            isBase64Encoded: false,
            rawQueryString: headUri.query ?? "",
            queryStringParameters: queryParams ?? [:],
            headers: mappedHeaders ?? [:]
        )
        
        let jsonData = try JSONEncoder().encode(gatewayRequest)
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            fatalError("Failed to encode proxy request as JSON string")
        }
        print("Forwarding:\n---\n\(jsonString)\n---\n")
        
        Task {
            do {
                var req = URLRequest(url: self.options.lambdaUrl)
                req.httpMethod = "POST"
                req.httpBody = jsonData
                
                let (data, resp) = try await URLSession.shared.data(for: req)
                
                guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
                    fatalError("Proxy request didn't yield a response")
                }
                
                guard let respString = String(data: data, encoding: .utf8) else {
                    fatalError("Failed to decode response as UTF8 string")
                }
                print("Response (\(httpResp.statusCode)):\n---\n\(respString)\n---\n")
                
                let respStruct = try JSONDecoder().decode(FakeApiGatewayResponse.self, from: ByteBuffer(data: data))
                
                callback(respStruct)
            } catch {
                fatalError("Failed to forward: \(error)")
            }
        }
    }
}
