//
//  File.swift
//  
//
//  Created by Janis Kirsteins on 21/12/2021.
//

import Foundation

struct FakeApiGatewayResponse : Codable
{
    let body: String?
    let statusCode: Int
    let headers: [String:String]
    let isBase64Encoded: Bool
}
