import Fluent

struct CreateOrganization: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Organization.schema)
            .id()
            .field("name", .string, .required)
            .field("api_key", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "api_key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Organization.schema).delete()
    }
}
