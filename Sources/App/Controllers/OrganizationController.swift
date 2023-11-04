import Foundation
import Fluent
import Vapor
import FirebaseJWTMiddleware
import MixpanelVapor

enum OrganizationRoleDTO: String, Content {
    case admin
    case editor
    case lurker
}

struct OrganizationMemberDTO: Content {
    var profile: ProfileLiteDTO
    var role: OrganizationRoleDTO
}

struct OrganizationDTO: Content {
    var id: UUID
    var name: String
    var members: [OrganizationMemberDTO]
}

extension Organization {
    func toDTO() throws -> OrganizationDTO {
        guard let id else {
            throw Abort(.internalServerError, reason: "missing organization id")
        }
        
        let members: [OrganizationMemberDTO] = try organizationRoles.map { role in
            
            let roleDTO: OrganizationRoleDTO
            switch role.role {
            case .admin:
                roleDTO = .admin
            case .editor:
                roleDTO = .editor
            case .lurker:
                roleDTO = .lurker
            }
            
            return try .init(profile: role.profile.toLiteDTO(), role: roleDTO)
        }
                
        return .init(id: id, name: name, members: members)
    }
}

struct OrganizationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let organizations = routes.grouped("organization")
        organizations.get(use: index)
        organizations.post(use: create)
        organizations.group(":organizationID") { organization in
            organization.patch(use: patch)
            organization.delete(use: delete)
            organization.group("members", ":profileID") { members in
                members.put(use: putOrganizationMembership)
                members.delete(use: deleteOrganizationMembership)
            }
        }
    }

    func index(req: Request) async throws -> [OrganizationDTO] {
        let profile = try await req.profile
        try await profile.$organizations.load(on: req.db)
        return try profile.organizations.map({ try $0.toDTO() })
    }

    func create(req: Request) async throws -> OrganizationDTO {
        let profile = try await req.profile
        
        struct OrganizationCreateDTO: Content, Validatable {
            var name: String
            
            static func validations(_ validations: inout Validations) {
                validations.add("name", as: String.self, is: .count(1...100))
            }
        }
        
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
        
        await req.mixpanel.track(name: "organization_created", request: req, params: ["email": profile.email, "organization_id": "\(organizationId)"])
        
        return try organization.toDTO()
    }
    
    func patch(req: Request) async throws -> OrganizationDTO {
        let profile = try await req.profile
        
        guard let organizationId = req.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
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
        
        let organization = role.organization
        
        struct OrganizationUpdateDTO: Content, Validatable {
            var name: String?
            
            static func validations(_ validations: inout Validations) {
                validations.add("name", as: String?.self, is: .nil || .count(1...100), required: false)
            }
        }
        
        let updateParams = try req.content.decode(OrganizationUpdateDTO.self)
        
        
        organization.name = updateParams.name ?? organization.name
        
        try await organization.update(on: req.db)
        
        try await organization.$organizationRoles.load(on: req.db)
        
        for organizationRole in organization.organizationRoles {
            try await organizationRole.$profile.load(on: req.db)
        }
        
        await req.mixpanel.track(name: "organization_updated", request: req, params: ["email": profile.email, "organization_id": "\(organizationId)"])
        
        return try organization.toDTO()
    }

    func delete(req: Request) async throws -> HTTPStatus {
        print("xxx delete organization")
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
      
        await req.mixpanel.track(name: "organization_deleted", request: req, params: ["email": profile.email, "organization_id": "aaa"])
        
        return .noContent
    }
    
    func putOrganizationMembership(req: Request) async throws -> OrganizationMemberDTO {
        
        let profile = try await req.profile
        
        guard let profileId = profile.id else {
            throw Abort(.internalServerError)
        }
        
        guard let organizationId = req.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        guard let profileToUpdateId = req.parameters.get("profileID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        guard try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileId)
            .filter(Organization.self, \.$id == organizationId)
            .filter(\.$role == .admin) // only admins can add people
            .first() != nil else {
            
            throw Abort(.unauthorized)
        }
        
        struct UpdateRoleDTO: Content {
            var role: OrganizationRoleDTO
        }
        
        let update = try req.content.decode(UpdateRoleDTO.self)
        
        if let currentRole = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileToUpdateId)
            .filter(Organization.self, \.$id == organizationId)
            .first() {
            
            switch update.role {
            case .admin:
                currentRole.role = .admin
            case .editor:
                currentRole.role = .editor
            case .lurker:
                currentRole.role = .lurker
            }
            
            try await currentRole.update(on: req.db)
            return try OrganizationMemberDTO(profile: currentRole.profile.toLiteDTO(), role: update.role)
        } else {
            
            guard let organization = try await Organization.find(organizationId, on: req.db) else {
                throw Abort(.notFound)
            }
            
            guard let profileToAdd = try await Profile.find(profileToUpdateId, on: req.db) else {
                throw Abort(.notFound)
            }
            
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
            
            return try OrganizationMemberDTO(profile: profileToAdd.toLiteDTO(), role: update.role)
        }
    }
    
    func deleteOrganizationMembership(req: Request) async throws -> HTTPStatus {
        
        let profile = try await req.profile
        
        guard let profileId = profile.id else {
            throw Abort(.internalServerError)
        }
        
        guard let organizationId = req.parameters.get("organizationID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        guard let profileToRemoveId = req.parameters.get("profileID").flatMap({ UUID(uuidString: $0) }) else {
            throw Abort(.badRequest)
        }
        
        guard try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileId)
            .filter(Organization.self, \.$id == organizationId)
            .filter(\.$role == .admin) // only admins can add people
            .first() != nil else {
            
            throw Abort(.unauthorized)
        }
        
        guard let profileToDeleteRole = try await ProfileOrganizationRole
            .query(on: req.db)
            .join(Organization.self, on: \ProfileOrganizationRole.$organization.$id == \Organization.$id)
            .join(Profile.self, on: \ProfileOrganizationRole.$profile.$id == \Profile.$id)
            .filter(Profile.self, \.$id == profileToRemoveId)
            .filter(Organization.self, \.$id == organizationId)
            .first() else {
            
            throw Abort(.notFound)
        }
        
        try await profileToDeleteRole.delete(on: req.db)
        
        return .noContent
    }
}
