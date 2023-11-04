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
            .field("role", organizationRoles, .required)
            .field("profile_id", .uuid, .references(Profile.schema, "id", onDelete: .cascade))
            .field("organization_id", .uuid, .references(Organization.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "profile_id", "organization_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ProfileOrganizationRole.schema).delete()
        try await database.enum("organization_roles").delete()
    }
}
