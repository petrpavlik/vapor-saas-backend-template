//
//  File.swift
//  
//
//  Created by Petr Pavlik on 11.03.2024.
//

import Fluent
import Vapor

final class OrganizationInvite: Model, Content, @unchecked Sendable {
    static let schema = "organization_invites"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: .email)
    var email: String
    
    @Field(key: .role)
    var role: ProfileOrganizationRole.Role

    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?
    
    @Parent(key: .organizationId)
    var organization: Organization

    init() { }

    init(id: UUID? = nil, email: String, role: ProfileOrganizationRole.Role, organization: Organization) throws {
        self.id = id
        self.email = email
        self.role = role
        self.$organization.id = try organization.requireID()
    }
}
