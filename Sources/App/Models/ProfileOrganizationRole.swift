import Fluent
import Vapor

final class ProfileOrganizationRole: Model, @unchecked Sendable {

    enum Role: String, Codable, Comparable {
        
        static func < (lhs: ProfileOrganizationRole.Role, rhs: ProfileOrganizationRole.Role) -> Bool {
            let order: [Role] = [.lurker, .editor, .admin]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
        
        case admin
        case editor
        case lurker
    }

    static let schema = "organization+profile"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: .profileId)
    var profile: Profile

    @Parent(key: .organizationId)
    var organization: Organization

    @Enum(key: "role")
    var role: Role
    
    @Timestamp(key: .createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: .updatedAt, on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, profile: Profile, organization: Organization, role: Role) throws {
        self.id = id
        self.$profile.id = try profile.requireID()
        self.$organization.id = try organization.requireID()
        self.role = role
    }
}
