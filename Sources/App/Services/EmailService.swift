import Vapor
import IndiePitcherSwift

protocol EmailService {
    func sendEmail(to: String, subject: String, markdown: String) async throws
    func sendPersonalizedEmail(to: String, subject: String, markdown: String, mailingList: String, delay: TimeInterval) async throws
    func syncContact(profile: Profile, subscribedToLists: Set<String>?) async throws
}

struct IndiePitcherEmailService: EmailService {
    
    private let indiePitcher: IndiePitcher
    
    init(application: Application) {
        
        guard let apiKey = Environment.get("IP_V2_SECRET_API_KEY") else {
            fatalError("IP_V2_SECRET_API_KEY env key missing")
        }
        
        indiePitcher = .init(client: application.http.client.shared,
                             apiKey: apiKey)
    }
    
    func sendEmail(to: String, subject: String, markdown: String) async throws {
        try await indiePitcher.sendEmail(data: .init(to: to,
                                                     subject: subject,
                                                     body: markdown,
                                                     bodyFormat: .markdown))
    }
    
    func sendPersonalizedEmail(to: String, subject: String, markdown: String, mailingList: String, delay: TimeInterval) async throws {
        try await indiePitcher.sendEmailToContact(data: .init(contactEmail: to,
                                                              subject: subject,
                                                              body: markdown,
                                                              bodyFormat: .markdown,
                                                              list: mailingList,
                                                              delaySeconds: delay))
    }
    
    func syncContact(profile: Profile, subscribedToLists: Set<String>?) async throws {
        try await indiePitcher.addContact(contact: .init(email: profile.email,
                                                         userId: try profile.requireID().uuidString,
                                                         avatarUrl: profile.avatarUrl,
                                                         name: profile.name,
                                                         updateIfExists: true,
                                                         subscribedToLists: subscribedToLists))
    }
}

// TODO: Log what methods are being called with what params for confirmation
struct MockEmailService: EmailService {
    
    func sendEmail(to: String, subject: String, markdown: String) async throws {
        
    }
    
    func sendPersonalizedEmail(to: String, subject: String, markdown: String, mailingList: String, delay: TimeInterval) async throws {
        
    }
    
    func syncContact(profile: Profile, subscribedToLists: Set<String>?) async throws {
        
    }
    
    
}

extension Application.Services {
    var emailService: Application.Service<EmailService> {
        .init(application: self.application)
    }
}

extension Request.Services {
    var emailService: EmailService {
        request.application.services.emailService.service
    }
}
