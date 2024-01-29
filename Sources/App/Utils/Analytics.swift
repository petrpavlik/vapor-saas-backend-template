//
//  File.swift
//  
//
//  Created by Petr Pavlik on 29.01.2024.
//

import Foundation
import Vapor
import MixpanelVapor

extension Request {
    func trackAnalyticsEvent(name: String, params: [String: any Content] = [:]) async {
        
        guard application.environment.isRelease else {
            return
        }
        
        var params = params
        if let profile = try? await profile {
            
            if let profileId = profile.id {
                params["$user_id"] = profileId.uuidString
            }
            
            params["$email"] = profile.email
            
            if let name = profile.name {
                params["$name"] = name
            }
            if let avatarUrl = profile.avatarUrl {
                params["$avatar"] = avatarUrl
            }
        }
        
        // Log to a destination of your choice
        await mixpanel.track(name: name, request: self, params: params)
    }
}
