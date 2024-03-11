import Fluent

struct CreateOrganization: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Organization.schema)
            .id()
            .field(.name, .string, .required)
            .field(.apiKey, .string)
            .field(.createdAt, .datetime)
            .field(.updatedAt, .datetime)
            .unique(on: .apiKey)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Organization.schema).delete()
    }
}
