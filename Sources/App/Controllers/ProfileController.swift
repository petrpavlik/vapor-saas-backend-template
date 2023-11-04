import Fluent
import Vapor
import FirebaseJWTMiddleware
import MixpanelVapor

extension Request {
    var profile: Profile {
        get async throws {
            let token = try await self.firebaseJwt.asyncVerify()
            if let profile = try await Profile.query(on: self.db).filter(\.$firebaseUserId == token.userID).first() {
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
}

struct ProfileLiteDTO: Content {
    var id: UUID
    var email: String
}

extension Profile {
    func toDTO() throws -> ProfileDTO {
        guard let id else {
            throw Abort(.internalServerError, reason: "missing profile id")
        }
        
        return .init(id: id, email: email, isSubscribedToNewsletter: subscribedToNewsletterAt != nil)
    }
    
    func toLiteDTO() throws -> ProfileLiteDTO {
        guard let id else {
            throw Abort(.internalServerError, reason: "missing profile id")
        }
        
        return .init(id: id, email: email)
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
        if let profile = try await Profile.query(on: req.db).filter(\.$firebaseUserId == token.userID).first() {

            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }

            guard email == profile.email else {
                // TODO: We don't currently support changing the email addresses of profiles.
                throw Abort(.badRequest, reason: "Firebase user email does not match profile email.")
            }
            
            await req.mixpanel.track(name: "profile_created", request: req, params: ["email": email])

            return try profile.toDTO()
        } else {
            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }
            let profile = Profile(firebaseUserId: token.userID, email: email)
            try await profile.save(on: req.db)
            return try profile.toDTO()
        }
    }
    
    func update(req: Request) async throws -> ProfileDTO {
        let profile = try await req.profile
        
        struct ProfileUpdateDTO: Content {
            var isSubscribedToNewsletter: Bool?
        }
        
        let update = try req.content.decode(ProfileUpdateDTO.self)
        
        if let isSubscribedToNewsletter = update.isSubscribedToNewsletter {
            if isSubscribedToNewsletter && profile.subscribedToNewsletterAt == nil {
                profile.subscribedToNewsletterAt = Date()
                await req.mixpanel.track(name: "profile_subscribed_to_newsletter", request: req, params: ["email": profile.email])
            } else if profile.subscribedToNewsletterAt != nil {
                profile.subscribedToNewsletterAt = nil
                await req.mixpanel.track(name: "profile_unsubscribed_from_newsletter", request: req, params: ["email": profile.email])
            }
        }
        
        try await profile.update(on: req.db)
        
        return try profile.toDTO()
    }

    func delete(req: Request) async throws -> HTTPStatus {
        // TODO: delete org if it's the last admin member
        let profile = try await req.profile
        try await req.profile.delete(on: req.db)
        await req.mixpanel.track(name: "profile_deleted", request: req, params: ["email": profile.email])
        return .noContent
    }
}
