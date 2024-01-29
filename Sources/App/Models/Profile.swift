import Fluent
import Vapor

final class Profile: Model, Content {
    static let schema = "profiles"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "firebase_user_id")
    var firebaseUserId: String

    @Field(key: "email")
    var email: String

    @OptionalField(key: "subscribed_to_newsletter_at")
    var subscribedToNewsletterAt: Date?
    
    @OptionalField(key: "name")
    var name: String?
    
    @OptionalField(key: "avatar_url")
    var avatarUrl: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
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
