import Testing
import VaporTesting

@testable import App

// TODO: make the DTOs conform to Equatable and compare the whole DTOs

extension Application {
    static func configuredAppForTests() async throws -> Application {
        let app = try await Application.make(.testing)
        try await configure(app)

        try await app.autoRevert()
        try await app.autoMigrate()

        return app
    }

    func createProfile(authToken: String) async throws -> ProfileDTO {
        var authHeader = HTTPHeaders()
        authHeader.bearerAuthorization = .init(token: authToken)

        var profile: ProfileDTO!

        try await test(
            .POST, "profile", headers: authHeader,
            afterResponse: { res async throws in
                #expect(res.status == .ok)
                profile = try res.content.decode(ProfileDTO.self)
            })

        return profile
    }
}

@Suite("App Tests with DB", .serialized)
struct AppTests {
    private func withApp(_ test: (Application) async throws -> Void) async throws {
        let app = try await Application.configuredAppForTests()
        do {
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    @Test("ProfileController")
    func testProfileController() async throws {
        try await withApp { app in

            #expect(try await Profile.query(on: app.db).count() == 0)

            var authHeader = HTTPHeaders()
            let firebaseToken = try await app.client.firebaseDefaultUserToken()
            authHeader.bearerAuthorization = .init(token: firebaseToken)

            try await app.testing().test(.POST, "profile", headers: authHeader) { res in
                #expect(res.status == .ok)
                let profile = try res.content.decode(ProfileDTO.self)
                #expect(profile.email == Environment.get("TEST_FIREBASE_USER_EMAIL"))
                #expect(profile.isSubscribedToNewsletter == false)
            }

            #expect(try await Profile.query(on: app.db).count() == 1)

            // default organization is created
            #expect(try await Organization.query(on: app.db).count() == 1)
            #expect(try await ProfileOrganizationRole.query(on: app.db).count() == 1)

            try await app.testing().test(.POST, "profile", headers: authHeader) { res in
                #expect(res.status == .ok)
                let profile = try res.content.decode(ProfileDTO.self)
                #expect(profile.email == Environment.get("TEST_FIREBASE_USER_EMAIL"))
                #expect(profile.isSubscribedToNewsletter == false)
            }

            #expect(try await Profile.query(on: app.db).count() == 1)
            #expect(try await Organization.query(on: app.db).count() == 1)
            #expect(try await ProfileOrganizationRole.query(on: app.db).count() == 1)

            try await app.testing().test(.GET, "profile", headers: authHeader) { res in
                #expect(res.status == .ok)
                let profile = try res.content.decode(ProfileDTO.self)
                #expect(profile.email == Environment.get("TEST_FIREBASE_USER_EMAIL"))
                #expect(profile.isSubscribedToNewsletter == false)
            }

            struct PatchProfileBody: Content {
                var isSubscribedToNewsletter: Bool?
            }

            try await app.testing().test(.DELETE, "profile", headers: authHeader) { res in
                #expect(res.status == .noContent)
            }

            #expect(try await Profile.query(on: app.db).count() == 0)

            try await app.testing().test(.POST, "profile", headers: authHeader) { res in
                #expect(res.status == .ok)
                let profile = try res.content.decode(ProfileDTO.self)
                #expect(profile.email == Environment.get("TEST_FIREBASE_USER_EMAIL"))
                #expect(profile.isSubscribedToNewsletter == false)
            }

            #expect(try await Profile.query(on: app.db).count() == 1)
        }
    }

    @Test("OrganizationController")
    func testOrganizationController() async throws {
        try await withApp { app in
            #expect(try await Organization.query(on: app.db).count() == 0)

            var authHeader = HTTPHeaders()
            let firebaseToken = try await app.client.firebaseDefaultUserToken()
            authHeader.bearerAuthorization = .init(token: firebaseToken)

            try await app.testing().test(
                .POST, "profile", headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let profile = try res.content.decode(ProfileDTO.self)
                    #expect(profile.email == Environment.get("TEST_FIREBASE_USER_EMAIL"))
                    #expect(profile.isSubscribedToNewsletter == false)
                })

            #expect(try await Organization.query(on: app.db).count() == 1)

            struct OrganizationCreateDTO: Content {
                var name: String
            }

            var organizationId: UUID!

            try await app.testing().test(
                .POST, "organization", headers: authHeader,
                beforeRequest: { request async throws in
                    try request.content.encode(OrganizationCreateDTO(name: "Test Organization"))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    let organization = try res.content.decode(OrganizationDTO.self)
                    organizationId = organization.id
                    #expect(organization.name == "Test Organization")
                })

            #expect(try await Organization.query(on: app.db).count() == 2)

            try await app.testing().test(
                .GET, "organization", headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let organizations = try res.content.decode([OrganizationDTO].self)
                })

            try await app.testing().test(
                .PATCH, "organization/\(organizationId.uuidString)", headers: authHeader,
                beforeRequest: { request async throws in
                    try request.content.encode(OrganizationCreateDTO(name: "New name"))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    let organization = try res.content.decode(OrganizationDTO.self)
                    organizationId = organization.id
                    #expect(organization.name == "New name")
                })

            // create 2nd user
            var authHeader2 = HTTPHeaders()
            let firebaseToken2 = try await app.client.firebaseDefaultUser2Token()
            authHeader2.bearerAuthorization = .init(token: firebaseToken2)

            #expect(try await Organization.query(on: app.db).count() == 2)

            var user2Id = ""
            try await app.testing().test(
                .POST, "profile", headers: authHeader2,
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let profile = try res.content.decode(ProfileDTO.self)
                    #expect(profile.email == Environment.get("TEST_FIREBASE_USER_2_EMAIL"))
                    user2Id = profile.id.uuidString
                })

            #expect(try await Organization.query(on: app.db).count() == 3)

            struct UpdateRoleDTO: Content {
                var email: String
                var role: OrganizationRoleDTO
            }

            try await app.testing().test(
                .PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader,
                beforeRequest: { request in
                    try request.content.encode(
                        UpdateRoleDTO(
                            email: Environment.get("TEST_FIREBASE_USER_2_EMAIL")!, role: .lurker))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let member = try res.content.decode(OrganizationMemberDTO.self)
                    #expect(member.role == .lurker)
                })

            try await app.testing().test(
                .PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader,
                beforeRequest: { request in
                    try request.content.encode(
                        UpdateRoleDTO(
                            email: Environment.get("TEST_FIREBASE_USER_2_EMAIL")!, role: .editor))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let member = try res.content.decode(OrganizationMemberDTO.self)
                    #expect(member.role == .editor)
                })

            try await app.testing().test(
                .DELETE,
                "organization/\(organizationId.uuidString)/members/\(Environment.get("TEST_FIREBASE_USER_2_EMAIL")!)",
                headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .noContent)
                })

            try await app.testing().test(
                .PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader,
                beforeRequest: { request in
                    try request.content.encode(
                        UpdateRoleDTO(email: "unregistered@example.com", role: .admin))
                },
                afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    let member = try res.content.decode(OrganizationMemberDTO.self)
                    #expect(member.email == "unregistered@example.com")
                    #expect(member.role == .admin)
                })

            try await app.testing().test(
                .DELETE,
                "organization/\(organizationId.uuidString)/members/unregistered@example.com",
                headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .noContent)
                })

            #expect(try await Organization.query(on: app.db).count() == 3)

            try await app.testing().test(
                .DELETE, "organization/\(organizationId.uuidString)", headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .noContent)
                })

            #expect(try await Organization.query(on: app.db).count() == 2)
            #expect(try await Profile.query(on: app.db).count() == 2)

            try await app.testing().test(
                .DELETE, "profile", headers: authHeader2,
                afterResponse: { res async throws in
                    #expect(res.status == .noContent)
                })

            try await app.testing().test(
                .DELETE, "profile", headers: authHeader,
                afterResponse: { res async throws in
                    #expect(res.status == .noContent)
                })

            #expect(try await Profile.query(on: app.db).count() == 0)
        }
    }
}
