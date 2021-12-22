//
//  main.swift
//
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation
import NIO
import NIOHTTP1
import Lifecycle
import Logging

let options = ProxyOptions()

LoggingSystem.bootstrap {
    var result = StreamLogHandler.standardOutput(label: $0)
    result.logLevel = options.logLevel
    return result
}

@available(macOS 12.0, *)
class Proxy {
    let elg: EventLoopGroup
    let lifecycle: ServiceLifecycle
    let options: ProxyOptions
    let logger = Logger(label: String(reflecting: Proxy.self))
    
    init(options: ProxyOptions) {
        self.options = options
        self.lifecycle = ServiceLifecycle()
        self.elg =
        MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        self.lifecycle.registerShutdown(
            label: "eventLoopGroup",
            .sync(self.elg.syncShutdownGracefully)
        )
    }
    
    func startAndWait() {
        
        let reuseAddrOpt = ChannelOptions.socket(
            SocketOptionLevel(SOL_SOCKET),
            SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: self.elg)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
        
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    return channel.pipeline.addHandler(HTTPHandler(options: self.options))
                }
            }
        
            .childChannelOption(ChannelOptions.socket(
                IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,
                                value: 1)
        
        do {
            let serverChannel =
            try bootstrap.bind(host: self.options.listenHost, port: self.options.listenPort)
                .wait()
            
            self.logger.info("Listening on: \(serverChannel.localAddress!)")
            
            try lifecycle.startAndWait()
        }
        catch {
            fatalError("Proxy failed: \(error)")
        }
    }
}

if #available(macOS 12.0, *) {
    Proxy(options: options).startAndWait()
} else {
    fatalError("macOS 12.0 required")
}
