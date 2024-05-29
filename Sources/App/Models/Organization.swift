import Fluent
import Vapor

final class Organization: Model, Content, @unchecked Sendable {
    static let schema = "organizations"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: .name)
    var name: String

    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?

    @OptionalField(key: .apiKey)
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
