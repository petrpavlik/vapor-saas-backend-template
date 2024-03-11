//
//  File.swift
//  
//
//  Created by Petr Pavlik on 11.03.2024.
//

import Fluent

struct CreateOrganizationInvite: AsyncMigration {
    func prepare(on database: Database) async throws {
        
        try await database.schema(OrganizationInvite.schema)
            .id()
            .field(.email, .string, .required)
            .field(.role, .string, .required)
            .field(.createdAt, .datetime)
            .field(.updatedAt, .datetime)
            .field(.organizationId, .uuid, .references(Organization.schema, "id", onDelete: .cascade))
            .unique(on: .email)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(OrganizationInvite.schema).delete()
    }
}
