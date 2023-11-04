import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }

    try app.register(collection: ProfileController())
    try app.register(collection: OrganizationController())
}
