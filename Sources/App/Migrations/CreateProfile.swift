import Fluent

struct CreateProfile: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Profile.schema)
            .id()
            .field("firebase_user_id", .string, .required)
            .field("email", .string, .required)
            .field("subscribed_to_newsletter_at", .date)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "firebase_user_id")
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Profile.schema).delete()
    }
}
