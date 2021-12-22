//
//  FakeApiGatewayResponse.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation

/// Structure mimicking API Gateway response. Some fields may be missing.
struct FakeApiGatewayResponse : Codable
{
    let body: String?
    let statusCode: Int
    let headers: [String:String]
    let isBase64Encoded: Bool
}
