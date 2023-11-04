//
//  File.swift
//  
//
//  Created by Petr Pavlik on 29.10.2023.
//

import Foundation
import Vapor

private struct FirebaseSignInRequestDTO: Content {
    let email: String
    let password: String
    let returnSecureToken: Bool
}

private struct FirebaseSignInResponseDTO: Content {
    let idToken: String
}

extension Client {
    func firebaseUserToken(email: String, password: String) async throws -> String {
        
        guard let webApiKey = Environment.get("TEST_FIREBASE_WEB_API_KEY") else {
            throw Abort(.internalServerError, reason: "TEST_FIREBASE_WEB_API_KEY not defined in .env.testing")
        }

        let response = try await post("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(webApiKey)", content: FirebaseSignInRequestDTO(email: email, password: password, returnSecureToken: true))
        let decodedResponse = try response.content.decode(FirebaseSignInResponseDTO.self)
        return decodedResponse.idToken
    }
    
    func firebaseDefaultUserToken() async throws -> String {
                
        guard let email = Environment.get("TEST_FIREBASE_USER_EMAIL") else {
            throw Abort(.internalServerError, reason: "TEST_FIREBASE_USER_EMAIL not defined in .env.testing")
        }
        
        guard let password = Environment.get("TEST_FIREBASE_USER_PASSWORD") else {
            throw Abort(.internalServerError, reason: "TEST_FIREBASE_USER_PASSWORD not defined in .env.testing")
        }
        
        return try await firebaseUserToken(email: email, password: password)
    }
    
    func firebaseDefaultUser2Token() async throws -> String {
                
        guard let email = Environment.get("TEST_FIREBASE_USER_2_EMAIL") else {
            throw Abort(.internalServerError, reason: "TEST_FIREBASE_USER_2_EMAIL not defined in .env.testing")
        }
        
        guard let password = Environment.get("TEST_FIREBASE_USER_2_PASSWORD") else {
            throw Abort(.internalServerError, reason: "TEST_FIREBASE_USER_2_PASSWORD not defined in .env.testing")
        }
        
        return try await firebaseUserToken(email: email, password: password)
    }
}
