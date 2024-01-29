//
//  File.swift
//  
//
//  Created by Petr Pavlik on 21.01.2024.
//

import Vapor
import FirebaseJWTMiddleware

protocol JWTUser {
    var userID: String { get }
    var email: String? { get }
    var name: String? { get }
    var picture: String? { get }
}

extension FirebaseJWTPayload : JWTUser {
    
}

extension Request {
    var jwtUser: some JWTUser {
        get async throws {
            // This is where you can swap Firebase Auth for another JWT-based provider (Amazon Congnito, Clerk, ...)
            try await self.firebaseJwt.asyncVerify()
        }
    }
}
