import Fluent
import Vapor

final class Organization: Model, Content {
    static let schema = "organizations"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @OptionalField(key: "api_key")
    var apiKey: String?

    @Siblings(through: ProfileOrganizationRole.self, from: \.$organization, to: \.$profile)
    public var profiles: [Profile]
    
    @Children(for: \.$organization)
    public var organizationRoles: [ProfileOrganizationRole]

    init() { }

    init(id: UUID? = nil, name: String, apiKey: String? = nil) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
    }
}
