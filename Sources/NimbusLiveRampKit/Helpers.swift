//
//  Helpers.swift
//  NimbusLiveRampKit
//  Created on 9/9/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import CryptoKit

extension URLQueryItem {
    enum LiveRamp: String {
        case placementId = "pid"
        case implementationMethod = "atype"
        case identifierValue = "iv"
        case identifierType = "it"

        // Privacy
        case gppConsentString = "gpp"
        case gppSectionId = "gpp_sid"
        case consentValue = "cv"
        case consentType = "ct"
    }

    init(key: LiveRamp, value: String?) {
        self.init(name: key.rawValue, value: value)
    }
}

extension URLComponents {
    mutating func insert(identifiers: [LiveRamp.Identifier]) {
        var items = queryItems ?? []

        for identifier in identifiers {
            switch identifier {
            case .email(let email):
                guard let normalized = normalize(email: email) else { continue }
                
                for hash in normalized.hash(of: [.sha256, .sha1, .md5]) {
                    items.append(.init(key: .identifierType, value: "\(identifier.queryType)"))
                    items.append(.init(key: .identifierValue, value: hash))
                }
            case .phone(let phone):
                let hash = normalize(phone: phone).hash(of: .sha1)
                items.append(.init(key: .identifierType, value: "\(identifier.queryType)"))
                items.append(.init(key: .identifierValue, value: hash))
            case .custom(let accountId, let id):
                items.append(.init(key: .identifierType, value: "\(identifier.queryType)"))
                items.append(.init(key: .identifierValue, value: "\(accountId):\(id)"))
            }
        }

        queryItems = items
    }

    mutating func insert(envelopeResponse: LiveRamp.EnvelopeResponse) {
        var items = queryItems ?? []

        for envelope in envelopeResponse.envelopes where envelope.isRefreshable {
            items.append(.init(key: .identifierType, value: "\(envelope.rawType)"))
            items.append(.init(key: .identifierValue, value: envelope.value))
        }

        queryItems = items
    }

    // MARK: - Input normalization

    func normalize(email: String) -> String? {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.isValidEmail else { return nil }
        
        let parts = cleaned.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        var username = String(parts[0].split(separator: "+").first ?? parts[0])
        let domain = String(parts[1])
        if domain == "gmail.com" {
            username = username.replacingOccurrences(of: ".", with: "")
        }
        return "\(username)@\(domain)"
    }

    func normalize(phone: String) -> String {
        var digits = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        digits = digits.replacingOccurrences(of: "^0+(?!$)", with: "", options: .regularExpression)
        return digits
    }
}

extension URLRequest {
    func modifyingComponents(
        _ transform: (inout URLComponents) -> Void
    ) throws(LiveRampError) -> URLRequest {
        guard let url = url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { throw LiveRampError.requestFailure() }

        transform(&components)
        
        guard let newUrl = components.url else { throw LiveRampError.requestFailure() }

        var request = self
        request.url = newUrl
        return request
    }
}

enum HashType {
    case sha1
    case sha256
    case md5

    func hash(of data: Data) -> String {
        switch self {
        case .sha1:
            Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .md5:
            Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }
}

extension String {
    func hash(of hashType: HashType) -> String {
        hashType.hash(of: Data(self.utf8))
    }

    func hash(of hashTypes: [HashType]) -> [String] {
        let data = Data(self.utf8)
        return hashTypes.map { $0.hash(of: data) }
    }
    
    /// Uses iOS' NSDataDetector to avoid doing email validation ourselves
    var isValidEmail: Bool {
        guard let linkDetector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return false }
        
        let range = NSRange(startIndex..., in: self)
        let matches = linkDetector.matches(in: self, options: [], range: range)
        guard matches.count == 1, let match = matches.first else { return false }
        return match.url?.scheme == "mailto" && match.range == range
    }
}
