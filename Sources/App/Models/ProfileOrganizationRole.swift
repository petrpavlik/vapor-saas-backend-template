import Fluent
import Vapor

final class ProfileOrganizationRole: Model {

    enum Role: String, Codable { 
        case admin
        case editor
        case lurker 
    }

    static let schema = "organization+profile"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "profile_id")
    var profile: Profile

    @Parent(key: "organization_id")
    var organization: Organization

    @Enum(key: "role")
    var role: Role
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, profile: Profile, organization: Organization, role: Role) throws {
        self.id = id
        self.$profile.id = try profile.requireID()
        self.$organization.id = try organization.requireID()
        self.role = role
    }
}
