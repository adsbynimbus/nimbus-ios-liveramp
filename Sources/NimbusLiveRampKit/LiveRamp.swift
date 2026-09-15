//
//  LiveRamp.swift
//  NimbusLiveRampKit
//  Created on 9/2/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit
import os

fileprivate let logger = Logger(subsystem: Nimbus.Log.subsystem, category: "liveramp")

/// An error thrown while fetching or refreshing an identity envelope.
public enum LiveRampError: LocalizedError, Equatable {
    /// No `appId` was supplied and `Bundle.main.bundleIdentifier` was unavailable.
    case missingAppId
    
    /// No `identifier` was supplied. At least one identifier is required to initialize LiveRamp.
    case missingIdentifier
    
    /// The envelope endpoint returned no content, meaning the user is opted out
    case noEnvelope
    
    /// The request failed
    case requestFailure(String? = nil)

    public var errorDescription: String? {
        return switch self {
        case .missingAppId:
            "No app ID supplied and Bundle.main.bundleIdentifier was nil"
        case .missingIdentifier:
            "No identifie supplied. At least one identifier is required to initialize LiveRamp."
        case .noEnvelope:
            "No envelope returned - The user is opted out"
        case .requestFailure(let error):
            if let error { "Request failed: \(error)" }
            else { "Request failed" }
        }
    }
}

/// Retrieves, stores, and refreshes LiveRamp ATS identity envelopes, and applies
/// them to the Nimbus identity configuration.
///
/// Publishers provide a `placementId` and one or more user identifiers. Hashing,
/// normalization, consent parameters, storage, and refresh scheduling are handled
/// internally.
///
/// ```swift
/// try await LiveRamp.fetchEnvelope(
///     placementId: "14",
///     identifiers: .email("user@example.com")
/// )
/// ```
///
/// One envelope is stored at a time, for the app's current user. Call ``clear()``
/// together with ``Nimbus.configuration.identity.clear()`` on logout.
///
/// The placement must exist in [LiveRamp Console](https://launch.liveramp.com) in
/// an approved state, with the app's bundle ID registered on it.
///
/// For the underlying API, see the
/// [ATS API implementation guide for mobile publishers](https://developers.liveramp.com/authenticatedtraffic-api/docs/ats-api-implementation-guide-for-mobile-publishers).
public final class LiveRamp {
    private static let baseUrl = "https://api.rlcdn.com/api/identity/v2/envelope"
    private static let storedEnvelopeTTLSeconds: TimeInterval = 15 * 24 * 3600 // 15 days
    private static let refreshIntervalSeconds: TimeInterval = 30 * 60 // 30 minutes
    static let storedEnvelopeKey = "NimbusLiveRampKit.envelope"
    
    @MainActor
    private static var config: (placementId: String, appId: String)?
    
    /// A user identifier to exchange for an identity envelope.
    ///
    /// Pass raw user input; values are normalized and hashed before transmission.
    /// Custom identifiers are the exception and are sent unhashed, as LiveRamp
    /// expects.
    public enum Identifier: Sendable {
        /// An email address, sent as SHA-256, SHA-1, and MD5.
        case email(String)
        
        /// A phone number, sent as SHA-1. ATS supports phone-based matching for US numbers only.
        case phone(String)
        
        /// A publisher-issued identifier, sent unhashed as `accountId:id`.
        case custom(accountId: String, id: String)

        var queryType: Int {
            switch self {
            case .email: 4
            case .phone: 11
            case .custom: 15
            }
        }
    }

    /// Fetches an identity envelope and applies it to the Nimbus identity
    /// configuration.
    ///
    /// The stored envelope is reused where possible: one that is fresh is applied
    /// directly, one that is stale but within its time-to-live is refreshed, and
    /// anything older is replaced.
    ///
    /// - Parameters:
    ///   - placementId: The ATS placement ID from LiveRamp Console.
    ///   - identifiers: One or more user identifiers. This method will throw if empty array is passed
    ///   - appId: The bundle ID registered on the ATS placement. Defaults to
    ///     `Bundle.main.bundleIdentifier`. Pass this explicitly when the runtime
    ///     bundle ID differs from the registered one, as in build configurations
    ///     that append a suffix, or in app extensions.
    /// - Returns: The envelope response, already applied to Nimbus.
    /// - Throws: A ``LiveRampError`` for API-level failures, or a `URLError` if the
    ///   request itself did not complete. Task cancellation surfaces as
    ///   `URLError.cancelled`.
    @concurrent
    public static func initialize(
        placementId: String,
        identifiers: [Identifier],
        appId: String? = nil,
    ) async throws {
        guard identifiers.count > 0 else { throw LiveRampError.missingIdentifier }
        
        guard let appId = appId ?? Bundle.main.bundleIdentifier, !appId.isEmpty else {
            throw LiveRampError.missingAppId
        }

        try await updateEnvelope(placementId: placementId, appId: appId, identifiers: identifiers)
        
        Task { @MainActor in
            Self.config = (placementId: placementId, appId: appId)
            LiveRampExtension().install()
        }
    }
    
    @concurrent
    static func updateEnvelope(placementId: String, appId: String, identifiers: [Identifier] = []) async throws {
        let request = try prepareRequest(appId: appId, placementId: placementId)
        var response: EnvelopeResponse

        if let storedEnvelope = getEnvelope(),
           storedEnvelope.lastRefreshTime.addingTimeInterval(storedEnvelopeTTLSeconds) > Date() {
            guard storedEnvelope.lastRefreshTime.addingTimeInterval(refreshIntervalSeconds) < Date() else {
                logger.debug("Stored envelope was recently refreshed (\(storedEnvelope.lastRefreshTime)), not fetching a new one")
                return
            }

            logger.debug("Refreshing stored envelope")
            response = try await refreshEnvelope(
                request: request,
                storedResponse: storedEnvelope,
                identifiers: identifiers
            )
        } else {
            logger.debug("Requesting a new envelope")
            response = try await requestNewEnvelope(request: request, identifiers: identifiers)
        }

        response.lastRefreshTime = Date()
        store(response)
        await response.applyToNimbus()
    }
    
    static func updateEnvelope() async throws {
        guard let config = await config else { return }
        
        try await updateEnvelope(placementId: config.placementId, appId: config.appId)
    }

    /// Returns currently cached envelope or nil if none exists.
    public static func getEnvelope() -> EnvelopeResponse? {
        guard let data = UserDefaults.standard.data(forKey: storedEnvelopeKey) else { return nil }
        return try? JSONDecoder().decode(EnvelopeResponse.self, from: data)
    }

    /// Removes the stored envelope.
    ///
    /// Call this method on logout. ``Nimbus.configuration.identity.clear()`` should be called as well
    /// to clear the applied identity.
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: storedEnvelopeKey)
        Task { @MainActor in
            Self.config = nil
            LiveRampExtension.disable()
        }
    }
    
    /// Request Param types described in LiveRamp Docs: https://developers.liveramp.com/authenticatedtraffic-api/docs/4-call-the-ats-envelope-api
    static func prepareRequest(appId: String, placementId: String) throws(LiveRampError) -> URLRequest {
        guard var components = URLComponents(string: Self.baseUrl) else {
            throw LiveRampError.requestFailure()
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(key: .placementId, value: placementId),
            URLQueryItem(key: .implementationMethod, value: "2"),
        ]

        if let sectionId = Nimbus.IAB.gppSectionId, let consentString = Nimbus.IAB.gppConsentString {
            queryItems.append(URLQueryItem(key: .gppSectionId, value: sectionId))
            queryItems.append(URLQueryItem(key: .gppConsentString, value: consentString))
        }

        if let tcfString = Nimbus.IAB.tcfString {
            queryItems.append(URLQueryItem(key: .consentType, value: "4"))
            queryItems.append(URLQueryItem(key: .consentValue, value: tcfString))
        } else if let usPrivacyString = Nimbus.IAB.usPrivacyString {
            queryItems.append(URLQueryItem(key: .consentType, value: "3"))
            queryItems.append(URLQueryItem(key: .consentValue, value: usPrivacyString))
        }

        components.queryItems = queryItems

        guard let url = components.url else { throw LiveRampError.requestFailure() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("https://\(appId)", forHTTPHeaderField: "origin")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        return request
    }

    static func newEnvelopeRequest(
        from request: URLRequest,
        identifiers: [Identifier]
    ) throws(LiveRampError) -> URLRequest {
        guard !identifiers.isEmpty else {
            throw LiveRampError.requestFailure("Cannot request a new envelope without identifiers")
        }
        
        return try request.modifyingComponents { components in
            components.insert(identifiers: identifiers)
        }
    }

    /// API Reference: https://developers.liveramp.com/authenticatedtraffic-api/docs/7-implement-the-ats-refresh-envelope-api
    static func refreshRequest(
        from request: URLRequest,
        storedResponse: EnvelopeResponse
    ) throws(LiveRampError) -> URLRequest {
        try request.modifyingComponents { components in
            components.path += "/refresh"
            components.insert(envelopeResponse: storedResponse)
        }
    }

    static func requestNewEnvelope(
        request: URLRequest,
        identifiers: [Identifier]
    ) async throws -> EnvelopeResponse {
        let request = try newEnvelopeRequest(from: request, identifiers: identifiers)
        return try await perform(request: request)
    }

    /// This method refreshes stored envelopes and returns the response.
    ///
    /// API Reference: https://developers.liveramp.com/authenticatedtraffic-api/docs/7-implement-the-ats-refresh-envelope-api
    static func refreshEnvelope(
        request: URLRequest,
        storedResponse: EnvelopeResponse,
        identifiers: [Identifier]
    ) async throws -> EnvelopeResponse {
        do {
            let request = try refreshRequest(from: request, storedResponse: storedResponse)
            return try await perform(request: request)
        } catch LiveRampError.noEnvelope {
            logger.debug("Refreshing envelope failed - the envelope is expired, requesting a new one")
            let request = try newEnvelopeRequest(from: request, identifiers: identifiers)
            return try await perform(request: request)
        }
    }
    
    static func perform(request: URLRequest) async throws -> EnvelopeResponse {
        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw LiveRampError.requestFailure("Received non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(EnvelopeResponse.self, from: data)
            } catch {
                throw LiveRampError.requestFailure("Could not decode envelope, error: \(error)")
            }
        case 204:
            throw LiveRampError.noEnvelope
        default:
            throw LiveRampError.requestFailure("Unexpected HTTP status code: \(httpResponse.statusCode)")
        }
    }

    // Re-encoded rather than storing the raw response body, so createdAt and
    // lastRefreshTime persist alongside the envelopes.
    static func store(_ response: EnvelopeResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: storedEnvelopeKey)
    }
}
