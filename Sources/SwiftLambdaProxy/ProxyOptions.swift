//
//  ProxyOptions.swift
//  
//
//  Created by Janis Kirsteins on 22/12/2021.
//

import Foundation
import Logging

/// Proxy options specifiable via environment variables.
struct ProxyOptions {
    @FromEnv("LAMBDA_HOST") var lambdaHost: String = "127.0.0.1"
    @FromEnv("LAMBDA_PORT") var lambdaPort: Int = 7000
    
    @FromEnv("LISTEN_HOST") var listenHost: String = "127.0.0.1"
    @FromEnv("LISTEN_PORT") var listenPort: Int = 5000
    
    @FromEnv("LOG_LEVEL") var logLevel: Logger.Level = .info
    
    func getLambdaUrl() -> URL {
        URL(string: "http://\(lambdaHost):\(lambdaPort)/invoke")!
    }
}

protocol OptionParseable {
    associatedtype OutValue
    static func parse(name: String, value: String) -> OutValue
}

extension Logger.Level : OptionParseable {
    static func parse(name: String, value: String) -> Logger.Level
    {
        guard let result = Logger.Level(rawValue: value) else {
            fatalError("Environment value \(name) is not a valid log level.")
        }
        return result
    }
}

extension String : OptionParseable {
    static func parse(name: String, value: String) -> String
    {
        return value
    }
}

extension Int : OptionParseable {
    static func parse(name: String, value: String) -> Int
    {
        return (value as NSString).integerValue
    }
}

extension URL : OptionParseable {
    static func parse(name: String, value: String) -> URL
    {
        guard let result = URL(string: value) else {
            fatalError("Environment value \(name) could not be parsed to a URL.")
        }
        return result
    }
}

@propertyWrapper struct FromEnv<T>  {
    let wrappedValue: T
    
    /// Used when wrapped value is not optional and there is a default value
    init(wrappedValue defaultValue: T, _ envKey: String) where T: OptionParseable, T.OutValue == T {
        if let envValue = ProcessInfo.processInfo.environment[envKey] {
            self.wrappedValue = T.parse(name: envKey, value: envValue)
        } else {
            self.wrappedValue = defaultValue
        }
    }
    
    /// Used when wrapped value is not optional and there is no default value
    init(_ envKey: String) where T: OptionParseable, T.OutValue == T {
        if let envValue = ProcessInfo.processInfo.environment[envKey] {
            self.wrappedValue = T.parse(name: envKey, value: envValue)
        } else {
            fatalError("Environment value \(envKey) is mandatory.")
        }
    }
}
