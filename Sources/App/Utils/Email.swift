//
//  File.swift
//  
//
//  Created by Petr Pavlik on 29.01.2024.
//

import Foundation
import Vapor
import VaporSMTPKit
import SMTPKitten

extension Application {
    func sendEmail(subject: String, message: String, to email: String) async throws {
        guard try Environment.detect() != .testing else {
            return
        }
        
        // Following logic uses an email integrated through STMP to send your transactional emails
        // You can replace this with email provider of your choice, like Amazon SES, resend.com, or indiepitcher.com
        
        guard let smtpHostName = Environment.process.SMTP_HOSTNAME else {
            throw Abort(.internalServerError, reason: "SMTP_HOSTNAME env variable not defined")
        }
        
        guard let smtpEmail = Environment.process.SMTP_EMAIL else {
            throw Abort(.internalServerError, reason: "SMTP_EMAIL env variable not defined")
        }
        
        guard let smtpPassword = Environment.process.SMTP_PASSWORD else {
            throw Abort(.internalServerError, reason: "SMTP_PASSWORD env variable not defined")
        }
        
        let credentials = SMTPCredentials(
            hostname: smtpHostName,
            ssl: .startTLS(configuration: .default),
            email: smtpEmail,
            password: smtpPassword
        )
        
        let email = Mail(
            from: .init(name: "[name] from [company]", email: smtpEmail),
            to: [
                MailUser(name: nil, email: email)
            ],
            subject: subject,
            contentType: .plain, // supports html
            text: message
        )
        
        try await sendMail(email, withCredentials: credentials).get()
    }
}

extension Request {
    func sendEmail(subject: String, message: String, to: String) async throws {
        try await self.application.sendEmail(subject: subject, message: message, to: to)
    }
}
