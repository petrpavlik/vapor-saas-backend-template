import Foundation
import Fluent
import Vapor

enum OrganizationRoleDTO: String, Content {
    case admin
    case editor
    case lurker
}

struct OrganizationMemberDTO: Content {
    
    enum InvitationStatus: String, Content {
        case invited
        case joined
    }
    
    var email: String
    var role: OrganizationRoleDTO
    var status: InvitationStatus
}

struct OrganizationDTO: Content {
    var id: UUID
    var name: String
    var apiKey: String?
}

struct OrganizationUpdateDTO: Content, Validatable {
    var name: String?
    var resetApiKey: Bool?
    var deleteApiKey: Bool?
    
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String?.self, is: .nil || !.empty, required: false)
    }
}

extension Organization {
    func toDTO() throws -> OrganizationDTO {
        return .init(id: try requireID(), name: name, apiKey: apiKey)
    }
}

extension ProfileOrganizationRole.Role {
    func toDTO() -> OrganizationRoleDTO {
        switch self {
        case .admin:
            return .admin
        case .editor:
            return .editor
        case .lurker:
            return .lurker
        }
    }
}

extension ProfileOrganizationRole {
    func toDTO() throws -> OrganizationMemberDTO {
        .init(email: profile.email, role: role.toDTO(), status: .joined)
    }
}

extension OrganizationInvite {
    func toDTO() throws -> OrganizationMemberDTO {
        .init(email: email, role: role.toDTO(), status: .invited)
    }
}

extension Request {
    func organization(minRole: ProfileOrganizationRole.Role) async throws -> Organization {
        guard let organizationId = self.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        let profile = try await self.profile
        
        guard let profileId = profile.id else {
            throw Abort(.internalServerError)
        }
        
        guard let membership = try await ProfileOrganizationRole
            .query(on: self.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileId)
            .filter(Organization.self, \.$id == organizationId)
            .first() else {
            
            throw Abort(.unauthorized)
        }
        
        guard membership.role >= minRole else {
            throw Abort(.unauthorized)
        }
        
        try await membership.$organization.load(on: self.db)
        
        return membership.organization
    }
}

struct OrganizationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let organizations = routes.grouped("organization")
        organizations.get(use: index)
        organizations.post(use: create)
        organizations.group(":organizationID") { organization in
            organization.get(use: get)
            organization.patch(use: patch)
            organization.delete(use: delete)
            
            organization.group("members") { members in
                members.get(use: listOrganizationMemberships)
                members.put(use: putOrganizationMembership)
                members.post(use: putOrganizationMembership)
                members.group(":memberEmail") { member in
                    member.delete(use: deleteOrganizationMembership)
                }
            }
        }
    }

    @Sendable
    func index(req: Request) async throws -> [OrganizationDTO] {
        let profile = try await req.profile
        try await profile.$organizations.load(on: req.db)
        return try profile
            .organizations
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .map({ try $0.toDTO() })
    }
    
    @Sendable
    func get(req: Request) async throws -> OrganizationDTO {
        let organization = try await req.organization(minRole: .lurker)
        return try organization.toDTO()
    }

    @Sendable
    func create(req: Request) async throws -> OrganizationDTO {
        let profile = try await req.profile
        
        struct OrganizationCreateDTO: Content, Validatable {
            var name: String
            
            static func validations(_ validations: inout Validations) {
                validations.add("name", as: String.self, is: .count(1...100))
            }
        }
        
        try OrganizationCreateDTO.validate(content: req)
        let createParams = try req.content.decode(OrganizationCreateDTO.self)
        
        let organization = Organization(name: createParams.name)
        try await organization.create(on: req.db)
        
        try await organization.$profiles.attach(profile, on: req.db) { pivot in
            pivot.role = .admin
        }
        
        guard let organizationId = organization.id else {
            throw Abort(.internalServerError)
        }
        
        try await organization.$organizationRoles.load(on: req.db)
        
        for organizationRole in organization.organizationRoles {
            try await organizationRole.$profile.load(on: req.db)
        }
        
        await req.trackAnalyticsEvent(name: "organization_created", params: ["organization_id": "\(organizationId)"])
        
        return try organization.toDTO()
    }
    
    @Sendable
    func patch(req: Request) async throws -> OrganizationDTO {
        
        let organization = try await req.organization(minRole: .admin)
        
        try OrganizationUpdateDTO.validate(content: req)
        let updateParams = try req.content.decode(OrganizationUpdateDTO.self)
        
        
        organization.name = updateParams.name ?? organization.name
        
        if updateParams.deleteApiKey == true {
            organization.apiKey = nil
        } else if updateParams.resetApiKey == true {
            // FIXME: check if it's unique and retry like 3 times
            organization.apiKey = UUID().uuidString
        }
        
        try await organization.update(on: req.db)
        
        try await organization.$organizationRoles.load(on: req.db)
        
        for organizationRole in organization.organizationRoles {
            try await organizationRole.$profile.load(on: req.db)
        }
        
        await req.trackAnalyticsEvent(name: "organization_updated", params: ["organization_id": "\(organization.id?.uuidString ?? "???")"])
        
        return try organization.toDTO()
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let profile = try await req.profile
        
        guard let organizationId = req.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        try await profile.$organizationRoles.load(on: req.db)
        
        guard let profileId = profile.id else {
            throw Abort(.internalServerError)
        }
        
        guard let role = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileId)
            .filter(Organization.self, \.$id == organizationId)
            .filter(\.$role == .admin)
            .with(\.$organization)
            .first() else {
            
            throw Abort(.unauthorized)
        }
        
        try await role.organization.delete(on: req.db)
      
        await req.trackAnalyticsEvent(name: "organization_deleted", params: ["organization_id": "\(role.organization.id?.uuidString ?? "???")"])
        
        return .noContent
    }
    
    @Sendable
    func putOrganizationMembership(req: Request) async throws -> OrganizationMemberDTO {
        
        let profile = try await req.profile
        let organization = try await req.organization(minRole: .admin)
                
        guard let organizationId = req.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.internalServerError)
        }
        
        struct UpdateRoleDTO: Content, Validatable {
            var email: String
            var role: OrganizationRoleDTO
            
            static func validations(_ validations: inout Vapor.Validations) {
                validations.add("email", as: String.self, is: .email)
            }
        }
        
        try UpdateRoleDTO.validate(content: req)
        let update = try req.content.decode(UpdateRoleDTO.self)
        
        if let currentRole = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$email == update.email)
            .filter(Organization.self, \.$id == organizationId)
            .with(\.$profile)
            .with(\.$organization)
            .first() {
            
            let oldRole = currentRole.role
            
            switch update.role {
            case .admin:
                currentRole.role = .admin
            case .editor:
                currentRole.role = .editor
            case .lurker:
                currentRole.role = .lurker
            }
            
            if oldRole != currentRole.role {
                try await currentRole.update(on: req.db)
                
                await req.trackAnalyticsEvent(name: "organization_member_updated", params: ["organization_id": organizationId.uuidString, "member_email": currentRole.profile.email, "member_role": update.role.rawValue])
            }
            
            return OrganizationMemberDTO(email: update.email, role: update.role, status: .joined)
            
        } else {
            
            if let profileToAdd = try await Profile.query(on: req.db).filter(\.$email == update.email).first() {
                
                try await organization.$profiles.attach(profileToAdd, on: req.db) { pivot in
                    switch update.role {
                    case .admin:
                        pivot.role = .admin
                    case .editor:
                        pivot.role = .editor
                    case .lurker:
                        pivot.role = .lurker
                    }
                }
                
                await req.trackAnalyticsEvent(name: "organization_member_added", params: ["organization_id": organizationId.uuidString, "member_email": profileToAdd.email, "member_role": update.role.rawValue])
                
                let emailBody = """
                Hi \(profileToAdd.name?.split(separator: " ").first ?? "there"),
                
                This is an automated message to let you know that you've been added to organization \(organization.name) as \(update.role.rawValue) by \(profile.name ?? profile.email).
                """
                
                do {
                    try await req.sendEmail(subject: "You've been added to \(organization.name)", message: emailBody, to: update.email)
                } catch {
                    req.logger.error("\(error)")
                }
                
                return OrganizationMemberDTO(email: update.email, role: update.role, status: .joined)
                
            } else {
                
                if let invitation = try await OrganizationInvite.query(on: req.db).filter(\.$email == update.email).first() {
                    
                    let oldRole = invitation.role
                    switch update.role {
                    case .admin:
                        invitation.role = .admin
                    case .editor:
                        invitation.role = .editor
                    case .lurker:
                        invitation.role = .lurker
                    }
                    
                    if oldRole != invitation.role {
                        try await invitation.update(on: req.db)
                    }
                    
                    return OrganizationMemberDTO(email: update.email, role: update.role, status: .invited)
                    
                } else {
                    
                    let invitation = try OrganizationInvite(email: update.email, role: .admin, organization: organization)
                    try! await invitation.create(on: req.db)
                    
                    await req.trackAnalyticsEvent(name: "organization_member_invitation_created", params: ["organization_id": organizationId.uuidString, "member_email": update.email, "member_role": update.role.rawValue])
                    
                    let emailBody = """
                    Hi there,
                    
                    This is an automated message to let you know that you've been invited to organization \(organization.name) as \(update.role.rawValue) by \(profile.name ?? profile.email).
                    """
                    
                    do {
                        try await req.sendEmail(subject: "You've been ivited to \(organization.name)", message: emailBody, to: update.email)
                    } catch {
                        req.logger.error("\(error)")
                    }
                    
                    return OrganizationMemberDTO(email: update.email, role: update.role, status: .invited)
                }
                
            }
        }
    }
    
    @Sendable
    func deleteOrganizationMembership(req: Request) async throws -> HTTPStatus {
        
        let profile = try await req.profile
        let organization = try await req.organization(minRole: .admin)
        let organizationId = try organization.requireID()
        
        guard let memberEmail = req.parameters.get("memberEmail") else {
            throw Abort(.badRequest)
        }
        
        if let currentRole = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$email == memberEmail)
            .filter(Organization.self, \.$id == organizationId)
            .with(\.$profile)
            .with(\.$organization)
            .first() {
            
            if profile.email == currentRole.profile.email {
                // Don't allow to remove myself to avoid people from getting locked out.
                // Make this more sophisticated in the future
                throw Abort(.forbidden, reason: "Cannot remove yourself")
            }
            
            try await currentRole.delete(on: req.db)
            
            await req.trackAnalyticsEvent(name: "organization_member_removed", params: ["organization_id": organizationId.uuidString, "member_email": currentRole.profile.email])
            
        } else if let invitation = try await OrganizationInvite
            .query(on: req.db).filter(\.$email == memberEmail)
            .join(Organization.self, on: \OrganizationInvite.$organization.$id == \Organization.$id)
            .filter(Organization.self, \.$id == organizationId)
            .with(\.$organization)
            .first() {
            
            try await invitation.delete(on: req.db)
            
            await req.trackAnalyticsEvent(name: "organization_invitation_removed", params: ["organization_id": organizationId.uuidString, "invitation_email": invitation.email])
            
        } else {
            throw Abort(.notFound)
        }
        
        return .noContent
    }
    
    @Sendable
    func listOrganizationMemberships(req: Request) async throws -> [OrganizationMemberDTO] {
        let organization = try await req.organization(minRole: .lurker)
        let organizationId = try organization.requireID()
        
        let currentRoles = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Organization.self, \.$id == organizationId)
            .with(\.$profile)
            .with(\.$organization)
            .all()
            .map { item in
                try item.toDTO()
            }
        
        let currentinvitations = try await OrganizationInvite
            .query(on: req.db)
            .join(Organization.self, on: \OrganizationInvite.$organization.$id == \Organization.$id)
            .filter(Organization.self, \.$id == organizationId)
            .with(\.$organization)
            .all()
            .map { item in
                try item.toDTO()
            }
        
       return currentinvitations + currentRoles
    }
}
