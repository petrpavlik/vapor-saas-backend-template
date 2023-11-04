@testable import App
import XCTVapor
import Nimble

// TODO: make the DTOs conform to Equatable and compare the whole DTOs

final class AppTests: XCTestCase {
    
    private var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try await configure(app)
        
        try await app.autoRevert()
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        
        app.shutdown()
        app = nil
    }

    func testProfileController() async throws {
        
        await expect { try await Profile.query(on: self.app.db).count() } == 0

        var authHeader = HTTPHeaders()
        let firebaseToken = try await app.client.firebaseDefaultUserToken()
        authHeader.bearerAuthorization = .init(token: firebaseToken)

        try app.test(.POST, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Profile.query(on: self.app.db).count() } == 1
        
        try app.test(.POST, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        try app.test(.GET, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        struct PatchProfileBody: Content {
            var isSubscribedToNewsletter: Bool?
        }
        
        try app.test(.PATCH, "profile", headers: authHeader, beforeRequest: { request in
            try request.content.encode(PatchProfileBody(isSubscribedToNewsletter: true))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == true
        })
        
        try app.test(.DELETE, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .noContent
        })
        
        await expect { try await Profile.query(on: self.app.db).count() } == 0
        
        try app.test(.POST, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Profile.query(on: self.app.db).count() } == 1
    }
    
    func testOrganizationController() async throws {
        
        await expect { try await Organization.query(on: self.app.db).count() } == 0
        
        var authHeader = HTTPHeaders()
        let firebaseToken = try await app.client.firebaseDefaultUserToken()
        authHeader.bearerAuthorization = .init(token: firebaseToken)

        try app.test(.POST, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        struct OrganizationCreateDTO: Content {
            var name: String
        }
        
        var organizationId: UUID!
        
        try app.test(.POST, "organization", headers: authHeader, beforeRequest: { request in
            try request.content.encode(OrganizationCreateDTO(name: "Test Organization"))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let organization = try res.content.decode(OrganizationDTO.self)
            organizationId = organization.id
            expect(organization.name) == "Test Organization"
            expect(organization.members.count) == 1
            expect(organization.members.first?.profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(organization.members.first?.role) == .admin
        })
        
        await expect { try await Organization.query(on: self.app.db).count() } == 1
        
        try app.test(.PATCH, "organization/\(organizationId.uuidString)", headers: authHeader, beforeRequest: { request in
            try request.content.encode(OrganizationCreateDTO(name: "New name"))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let organization = try res.content.decode(OrganizationDTO.self)
            organizationId = organization.id
            expect(organization.name) == "New name"
            expect(organization.members.count) == 1
            expect(organization.members.first?.profile.email) == Environment.get("TEST_FIREBASE_USER_EMAIL")
            expect(organization.members.first?.role) == .admin
        })
        
        // create 2nd user
        var authHeader2 = HTTPHeaders()
        let firebaseToken2 = try await app.client.firebaseDefaultUser2Token()
        authHeader2.bearerAuthorization = .init(token: firebaseToken2)

        var user2Id = ""
        try app.test(.POST, "profile", headers: authHeader2, afterResponse: { res in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == Environment.get("TEST_FIREBASE_USER_2_EMAIL")
            user2Id = profile.id.uuidString
        })
        
        struct UpdateRoleDTO: Content {
            var role: OrganizationRoleDTO
        }
        
        try app.test(.PUT, "organization/\(organizationId.uuidString)/members/\(user2Id)", headers: authHeader, beforeRequest: { request in
            try request.content.encode(UpdateRoleDTO(role: .lurker))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let member = try res.content.decode(OrganizationMemberDTO.self)
            expect(member.role) == .lurker
        })
        
        try app.test(.DELETE, "organization/\(organizationId.uuidString)/members/\(user2Id)", headers: authHeader, afterResponse: { res in
            expect(res.status) == .noContent
        })
        
        try app.test(.DELETE, "organization/\(organizationId.uuidString)", headers: authHeader, afterResponse: { res in
            expect(res.status) == .noContent
        })
        
        await expect { try await Organization.query(on: self.app.db).count() } == 0
        await expect { try await Profile.query(on: self.app.db).count() } == 2
        
        try app.test(.DELETE, "profile", headers: authHeader2, afterResponse: { res in
            expect(res.status) == .noContent
        })
        
        try app.test(.DELETE, "profile", headers: authHeader, afterResponse: { res in
            expect(res.status) == .noContent
        })
    }
}
