//
//  LiveRamp.swift
//  NimbusLiveRampKit
//
//  Created on 19/07/22.
//  Copyright © 2022 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
@preconcurrency import LRAtsSDK

enum NimbusLiveRampError: LocalizedError, Equatable {
    case identifierNotFound
    case errorStatus
    case disabled
    case couldntInitialize(message: String)
    case couldntFetchEnvelope
    
    public var errorDescription: String? {
        switch self {
        case .identifierNotFound: return "No e-mail or phone number found"
        case .errorStatus: return "Couldn't initialize LiveRamp - LRAts.shared.status is .error"
        case .disabled: return "Couldn't initialize LiveRamp - it's disabled"
        case .couldntInitialize(let message): return "Couldn't initialize LiveRamp: \(message)"
        case .couldntFetchEnvelope: return "Couldn't fetch LiveRamp envelope, missing error object"
        }
    }
}

/// Nimbus helper for initializing LiveRamp and applying the envelope.
///
/// Uses Swift concurrency. Fetch the envelope and chain `applyToNimbus()`
/// to attach it to Nimbus.
///
/// ##### Usage
/// ```swift
/// let liveRamp = LiveRamp(
///     configId: "<liveRampConfigId>",
///     email: "<email>",
///     hasConsentForNoLegislation: true
/// )
///
/// try await liveRamp.fetchEnvelope().applyToNimbus()
/// ```
@MainActor
@preconcurrency
public final class LiveRamp {
    
    /// LiveRamp configuration identifier
    let configId: String
    
    /// Possible e-mail used as identifier
    let email: String?
    
    /// Possible phone number used as identifier
    let phoneNumber: String?
    
    /// Boolean for toggling LiveRamps's hasConsentForNoLegislation
    /// Should be set before initializing an instance of this class if needed
    private(set) var hasConsentForNoLegislation: Bool {
        get { LRAts.shared.hasConsentForNoLegislation }
        set { LRAts.shared.hasConsentForNoLegislation = newValue }
    }
    
    /**
     Initializes a NimbusLiveRamp instance
     
     - Parameters:
        - configId: LiveRamp's configuration identifier
        - email: E-mail of the user
        - phoneNumber: Phone number of the user
        - hasConsentForNoLegislation: Boolean for toggling LiveRamps's hasConsentForNoLegislation
     */
    private init(
        configId: String,
        email: String?,
        phoneNumber: String?,
        hasConsentForNoLegislation: Bool
    ) {
        self.configId = configId
        self.email = email
        self.phoneNumber = phoneNumber
        self.hasConsentForNoLegislation = hasConsentForNoLegislation
    }
    
    /**
     Initializes a NimbusLiveRamp instance
     
     - Parameters:
        - configId: LiveRamp's configuration identifier
        - email: E-mail of the user
        - hasConsentForNoLegislation: Boolean for toggling LiveRamps's hasConsentForNoLegislation
     */
    public convenience init(
        configId: String,
        email: String,
        hasConsentForNoLegislation: Bool = false
    ) {
        self.init(
            configId: configId,
            email: email,
            phoneNumber: nil,
            hasConsentForNoLegislation: hasConsentForNoLegislation
        )
    }
    
    /**
     Initializes a NimbusLiveRamp instance
     
     - Parameters:
        - configId: LiveRamp's configuration identifier
        - phoneNumber: Phone number of the user
        - hasConsentForNoLegislation: Boolean for toggling LiveRamps's hasConsentForNoLegislation
     */
    public convenience init(
        configId: String,
        phoneNumber: String,
        hasConsentForNoLegislation: Bool = false
    ) {
        self.init(
            configId: configId,
            email: nil,
            phoneNumber: phoneNumber,
            hasConsentForNoLegislation: hasConsentForNoLegislation
        )
    }
    
    /**
     Fetches and returns LiveRamp envelope. This method also initializes LiveRamp if needed.
     
     - Parameters:
        - isTestMode - LiveRamp init parameter
        - logToFileEnabled - LiveRamp init parameter
     */
    public func fetchEnvelope(isTestMode: Bool = false, logToFileEnabled: Bool = false) async throws -> LREnvelope {
        try await initLiveRamp(canRetry: true, isTestMode: isTestMode, logToFileEnabled: logToFileEnabled)
        
        let identifierData: LRIdentifierData
        
        if let email {
            identifierData = LREmailIdentifier(email)
        } else if let phoneNumber {
            identifierData = LRPhoneNumberIdentifier(phoneNumber)
        } else {
            throw NimbusLiveRampError.identifierNotFound
        }
        
        return try await withUnsafeThrowingContinuation { continuation in
            LRAts.shared.getEnvelope(identifierData) { envelope, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let envelope {
                    continuation.resume(returning: envelope)
                } else {
                    continuation.resume(throwing: NimbusLiveRampError.couldntFetchEnvelope)
                }
            }
        }
    }
    
    private func initLiveRamp(canRetry: Bool, isTestMode: Bool, logToFileEnabled: Bool = false) async throws {
        let configuration = LRAtsConfiguration(
            configID: configId,
            isTestMode: isTestMode,
            logToFileEnabled: logToFileEnabled
        )
        
        switch LRAts.shared.status {
        case .notInitialized:
            return try await withUnsafeThrowingContinuation { continuation in
                LRAts.shared.initialize(with: configuration) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        case .ready: // no-op, already initialized
            break
        case .loading:
            guard canRetry else { throw NimbusLiveRampError.couldntInitialize(message: "loading longer than 500 ms") }
            
            try await NimbusUtils.sleep(milliseconds: 500, toleranceMS: 100)
            return try await initLiveRamp(canRetry: false, isTestMode: isTestMode, logToFileEnabled: logToFileEnabled)
        case .error:
            throw NimbusLiveRampError.errorStatus
        case .disabled:
            throw NimbusLiveRampError.disabled
        @unknown default:
            Nimbus.Log.lifecycle.error("Unknown LiveRamp status: \(LRAts.shared.status)")
            throw NimbusLiveRampError.couldntInitialize(message: "Unknown LiveRamp status: \(LRAts.shared.status)")
        }
    }
}
