import Fluent
import Vapor

final class Profile: Model, Content, @unchecked Sendable {
    static let schema = "profiles"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: .firebaseUserId)
    var firebaseUserId: String

    @Field(key: .email)
    var email: String

    @OptionalField(key: .subscribedToNewsletterAt)
    var subscribedToNewsletterAt: Date?
    
    @OptionalField(key: .name)
    var name: String?
    
    @OptionalField(key: .avatarUrl)
    var avatarUrl: String?
    
    @OptionalField(key: .lastSeenAt)
    var lastSeenAt: Date?

    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?

    @Siblings(through: ProfileOrganizationRole.self, from: \.$profile, to: \.$organization)
    public var organizations: [Organization]
    
    @Children(for: \.$profile)
    public var organizationRoles: [ProfileOrganizationRole]

    init() { }

    init(id: UUID? = nil, firebaseUserId: String, email: String, name: String?, avatarUrl: String?, subscribedToNewsletterAt: Date? = nil) {
        self.id = id
        self.firebaseUserId = firebaseUserId
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.subscribedToNewsletterAt = subscribedToNewsletterAt
    }
}
