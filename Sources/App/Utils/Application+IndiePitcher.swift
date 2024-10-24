import Vapor
import IndiePitcherSwift

extension Request {
    var indiePitcher: IndiePitcher {
        guard let apiKey = Environment.get("IP_V2_SECRET_API_KEY") else {
            fatalError("IP_V2_SECRET_API_KEY env key missing")
        }

        return .init(client: application.http.client.shared, apiKey: apiKey)
    }
}

extension Application {
    var indiePitcher: IndiePitcher {
        guard let apiKey = Environment.get("IP_V2_SECRET_API_KEY") else {
            fatalError("IP_V2_SECRET_API_KEY env key missing")
        }

        return .init(client: http.client.shared, apiKey: apiKey)
    }
}
