import Fluent
import Vapor

extension Request {
    var profile: Profile {
        get async throws {

            let token = try await self.jwtUser
            if let profile = try await Profile.query(on: self.db).filter(
                \.$firebaseUserId == token.userID
            ).first() {

                let avatarUrl = token.picture?.replacingOccurrences(of: "\\/", with: "")

                if profile.name != token.name {
                    profile.name = token.name
                }

                if profile.avatarUrl != avatarUrl {
                    profile.avatarUrl = avatarUrl
                }

                let hasChanges = profile.hasChanges

                let now = Date.now
                let prevLastSeenAt = profile.lastSeenAt ?? .distantPast

                var shouldUpdateLastActive = false

                // do this only once a minute
                if prevLastSeenAt.distance(to: now) > 60 {
                    profile.lastSeenAt = now
                    try await profile.update(on: db)
                    shouldUpdateLastActive = true
                }

                if hasChanges {
                    try await identifyProfile(
                        profile: profile, req: self, isNewProfile: false, refreshMixpanelOnly: false
                    )
                } else if shouldUpdateLastActive {
                    try await identifyProfile(
                        profile: profile, req: self, isNewProfile: false, refreshMixpanelOnly: true)
                }

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
        return .init(
            id: try requireID(), email: email,
            isSubscribedToNewsletter: subscribedToNewsletterAt != nil, name: name,
            avatarUrl: avatarUrl)
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
        profile.delete(use: delete)
    }

    @Sendable
    func index(req: Request) async throws -> ProfileDTO {
        try await req.profile.toDTO()
    }

    @Sendable
    func create(req: Request) async throws -> ProfileDTO {
        let token = try await req.jwtUser
        let avatarUrl = token.picture?.replacingOccurrences(of: "\\/", with: "")
        if let profile = try await Profile.query(on: req.db).filter(
            \.$firebaseUserId == token.userID
        ).first() {

            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }

            guard email == profile.email else {
                // TODO: We don't currently support changing the email addresses of profiles.
                throw Abort(
                    .badRequest, reason: "Firebase user email does not match profile email.")
            }

            if profile.name != token.name {
                profile.name = token.name
                try await profile.update(on: req.db)
            }

            if profile.avatarUrl != avatarUrl {
                profile.avatarUrl = avatarUrl
                try await profile.update(on: req.db)
            }

            let hasChanges = profile.hasChanges

            profile.lastSeenAt = .now
            try await profile.update(on: req.db)

            if hasChanges {
                try await identifyProfile(
                    profile: profile, req: req, isNewProfile: false, refreshMixpanelOnly: false)
            }

            return try profile.toDTO()
        } else {
            guard let email = token.email else {
                throw Abort(.badRequest, reason: "Firebase user does not have an email address.")
            }

            let profile = Profile(
                firebaseUserId: token.userID, email: email, name: token.name, avatarUrl: avatarUrl)
            try await profile.save(on: req.db)

            let invites = try await OrganizationInvite.query(on: req.db).filter(
                \.$email == profile.email
            ).with(\.$organization).all()

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

            let profileId = try profile.requireID()

            req.services.analyticsService.track(
                profileId: profileId, name: "profile_created",
                params: [
                    "email": profile.email, "name": profile.name ?? "", "user_agent": userAgent,
                    "languages": languages,
                ])

            try await identifyProfile(
                profile: profile, req: req, isNewProfile: true, refreshMixpanelOnly: false)

            return try profile.toDTO()
        }
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let profile = try await req.profile
        let profileId = try profile.requireID()

        let organizations = try await profile.$organizations.get(on: req.db)
        for organization in organizations {
            let adminRoles = try await organization.$organizationRoles.get(on: req.db).filter({
                $0.role == .admin
            })
            if adminRoles.count == 1, adminRoles.first?.$profile.id == profileId {
                try await organization.delete(on: req.db)
            }
        }

        try await unidentifyProfile(profile: profile, req: req)
        try await profile.delete(on: req.db)
        req.services.analyticsService.track(profileId: nil, name: "profile_deleted", params: [:])
        return .noContent
    }
}

private func identifyProfile(
    profile: Profile, req: Request, isNewProfile: Bool, refreshMixpanelOnly: Bool
) async throws {
    var properties: [String: String] = [
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

    await req.services.analyticsService.peopleSet(profileId: profileId, setParams: properties)

    do {

        if refreshMixpanelOnly == false {
            try await req.services.emailService.syncContact(
                profile: profile,
                subscribedToLists: isNewProfile ? ["onboarding", "product_updates"] : nil)
        }

        if isNewProfile {
            await sendWelcomeOnboardingEmail(req: req, profile: profile)
        }

    } catch {
        req.logger.error("\(error)")
    }
}

private func unidentifyProfile(profile: Profile, req: Request) async throws {
    let profileId = try profile.requireID()
    await req.mixpanel.peopleDelete(distinctId: profileId.uuidString)
}

private func sendWelcomeOnboardingEmail(req: Request, profile: Profile) async {
    do {

        let body = """
            Hi {{firstName|default:"there"}},

            Thanks for signing up for Welcome to SaaS Backend Template.

            <br/>
            All the best in your startup endeavours.
            """

        try await req.services.emailService.sendPersonalizedEmail(
            to: profile.email, subject: "Welcome to SaaS Backend Template!", markdown: body,
            mailingList: "onboarding", delay: 60 * 5)
    } catch {
        // don't fail a request just because this has failed
        req.logger.error("\(error)")
    }
}
