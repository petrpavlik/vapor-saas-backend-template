import Fluent
import Vapor
import FirebaseJWTMiddleware

extension Request {
    var profile: Profile {
        get async throws {
            let token = try await self.firebaseJwt.asyncVerify()
            if let profile = try await Profile.query(on: self.db).filter(\.$firebaseUserId == token.userID).first() {
                
                profile.lastSeenAt = .now
                try await profile.update(on: db)
                
                return profile
                
            } else {
                throw Abort(.notFound, reason: "Profile not found.")
            }
        }
    }
}

struct ProfileDTO: Content {
    var id: UUID
    var email: String
    var isSubscribedToNewsletter: Bool
    var name: String?
    var avatarUrl: String?
}

struct ProfileLiteDTO: Content {
    var id: UUID
    var email: String
    var name: String?
    var avatarUrl: String?
}

extension Profile {
    func toDTO() throws -> ProfileDTO {
        return .init(id: try requireID(), email: email, isSubscribedToNewsletter: subscribedToNewsletterAt != nil, name: name, avatarUrl: avatarUrl)
    }
    
    func toLiteDTO() throws -> ProfileLiteDTO {
        return .init(id: try requireID(), email: email, name: name, avatarUrl: avatarUrl)
    }
}

struct ProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let profile = routes.grouped("profile")
        profile.get(use: index)
        profile.post(use: create)
        profile.patch(use: update)
        profile.delete(use: delete)
    }

    @Sendable
    func index(req: Request) async throws -> ProfileDTO {
        try await req.profile.toDTO()
    }

    @Sendable
    func create(req: Request) async throws -> ProfileDTO {
        let token = try await req.firebaseJwt.asyncVerify()
        let avatarUrl = token.picture?.replacingOccurrences(of: "\\/", with: "")
        if let profile = try await Profile.query(on: req.db).filter(\.$firebaseUserId == token.userID).first() {

            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }

            guard email == profile.email else {
                // TODO: We don't currently support changing the email addresses of profiles.
                throw Abort(.badRequest, reason: "Firebase user email does not match profile email.")
            }
            
            if profile.name != token.name {
                profile.name = token.name
                try await profile.update(on: req.db)
            }
            
            if profile.avatarUrl != avatarUrl {
                profile.avatarUrl = avatarUrl
                try await profile.update(on: req.db)
            }
            
            profile.lastSeenAt = .now
            try await profile.update(on: req.db)
            
            try await identifyProfile(profile: profile, req: req)

            return try profile.toDTO()
        } else {
            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }
            
            let profile = Profile(firebaseUserId: token.userID, email: email, name: token.name, avatarUrl: avatarUrl)
            try await profile.save(on: req.db)
            
            let invites = try await OrganizationInvite.query(on: req.db).filter(\.$email == profile.email).with(\.$organization).all()
            
            if invites.isEmpty {
                // Create default organization
                let organizationName: String
                if let usersName = token.name, usersName.isEmpty == false {
                    organizationName = "\(usersName)'s Organization"
                } else {
                    organizationName = "Default Organization"
                }
                
                let organization = Organization(name: organizationName)
                try await organization.create(on: req.db)
                
                try await organization.$profiles.attach(profile, on: req.db) { pivot in
                    pivot.role = .admin
                }
            } else {
                
                for invite in invites {
                    
                    try await invite.organization.$profiles.attach(profile, on: req.db) { pivot in
                        pivot.role = invite.role
                    }
                    
                    try await invite.delete(on: req.db)
                }
            }
            
            let userAgent = req.headers["User-Agent"].first ?? ""
            let languages = req.headers["Accept-Language"].first ?? ""
            
            await req.trackAnalyticsEvent(name: "profile_created", params: ["email": profile.email, "name": profile.name ?? "", "user_agent": userAgent, "languages": languages])
            
            try await identifyProfile(profile: profile, req: req)
            
            return try profile.toDTO()
        }
    }
    
    @Sendable
    func update(req: Request) async throws -> ProfileDTO {
        let profile = try await req.profile
        
        struct ProfileUpdateDTO: Content {
            var isSubscribedToNewsletter: Bool?
        }
        
//        try ProfileUpdateDTO.validate(content: req)
        let update = try req.content.decode(ProfileUpdateDTO.self)
        
        if let isSubscribedToNewsletter = update.isSubscribedToNewsletter {
            if isSubscribedToNewsletter && profile.subscribedToNewsletterAt == nil {
                profile.subscribedToNewsletterAt = Date()
                await req.trackAnalyticsEvent(name: "profile_subscribed_to_newsletter")
            } else if profile.subscribedToNewsletterAt != nil {
                profile.subscribedToNewsletterAt = nil
                await req.trackAnalyticsEvent(name: "profile_unsubscribed_from_newsletter")
            }
        }
        
        try await profile.update(on: req.db)
        
        try await identifyProfile(profile: profile, req: req)
        
        return try profile.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let profile = try await req.profile
        let profileId = try profile.requireID()
        
        let organizations = try await profile.$organizations.get(on: req.db)
        for organization in organizations {
            let adminRoles = try await organization.$organizationRoles.get(on: req.db).filter({ $0.role == .admin })
            if adminRoles.count == 1, adminRoles.first?.$profile.id == profileId {
                try await organization.delete(on: req.db)
            }
        }
        
        try await unidentifyProfile(profile: profile, req: req)
        try await profile.delete(on: req.db)
        await req.trackAnalyticsEvent(name: "profile_deleted")
        return .noContent
    }
    
    // MARK: Analytics
    
    private func identifyProfile(profile: Profile, req: Request) async throws {
        var properties: [String: any Content] = [
            "$email": profile.email
        ]
        
        if let name = profile.name {
            properties["$name"] = name
        }
        
        if let avatar = profile.avatarUrl {
            properties["$avatar"] = avatar
        }
        
        if let createdAt = profile.createdAt {
            properties["$created"] = createdAt.description
        }
        
        let profileId = try profile.requireID()
        
        await req.mixpanel.peopleSet(distinctId: profileId.uuidString, request: req, setParams: properties)
    }
    
    private func unidentifyProfile(profile: Profile, req: Request) async throws {
        let profileId = try profile.requireID()
        await req.mixpanel.peopleDelete(distinctId: profileId.uuidString)
    }
}
