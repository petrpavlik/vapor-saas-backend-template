import Fluent

struct CreateProfileOrganizationRole: AsyncMigration {
    func prepare(on database: Database) async throws {
        
        let organizationRoles = try await database.enum("organization_roles")
            .case("admin")
            .case("editor")
            .case("lurker")
            .create()
        
        try await database.schema(ProfileOrganizationRole.schema)
            .id()
            .field(.role, organizationRoles, .required)
            .field(.profileId, .uuid, .references(Profile.schema, "id", onDelete: .cascade))
            .field(.organizationId, .uuid, .references(Organization.schema, "id", onDelete: .cascade))
            .field(.createdAt, .datetime)
            .field(.updatedAt, .datetime)
            .unique(on: .profileId, .organizationId)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ProfileOrganizationRole.schema).delete()
        try await database.enum("organization_roles").delete()
    }
}
