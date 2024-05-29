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
        
        let profile = try? await profile
        
        await mixpanel.track(distinctId: profile?.id?.uuidString, name: name, request: self, params: params)
    }
}
