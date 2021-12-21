import Foundation
import NIO
import NIOHTTP1
import Lifecycle

struct ProxyOptions {
    let lambdaUrl: URL
}

let options = ProxyOptions(lambdaUrl: URL(string: "http://localhost:7000/invoke")!)

@available(macOS 12.0, *)
class Proxy {
    let elg: EventLoopGroup
    let lifecycle: ServiceLifecycle
    let options: ProxyOptions
    
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
            try bootstrap.bind(host: "localhost", port: 5000)
                .wait()
            print("Server running on:", serverChannel.localAddress!)
            
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
