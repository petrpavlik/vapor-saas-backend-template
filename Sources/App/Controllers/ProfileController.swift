import Fluent
import Vapor
import FirebaseJWTMiddleware

extension Request {
    var profile: Profile {
        get async throws {
            let token = try await self.jwtUser
            if let profile = try await Profile.query(on: self.db).filter(\.$firebaseUserId == token.userID).first() {
                
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

    func index(req: Request) async throws -> ProfileDTO {
        try await req.profile.toDTO()
    }

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
            
            try await profile.update(on: req.db)
            

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
            
            await req.trackAnalyticsEvent(name: "profile_created")
            
            return try profile.toDTO()
        }
    }
    
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
        
        return try profile.toDTO()
    }

    func delete(req: Request) async throws -> HTTPStatus {
        // TODO: delete org if it's the last admin member
        try await req.profile.delete(on: req.db)
        await req.trackAnalyticsEvent(name: "profile_deleted")
        return .noContent
    }
}
