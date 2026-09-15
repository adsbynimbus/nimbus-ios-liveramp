//
//  LiveRampTests.swift
//  NimbusLiveRampKitTests
//  Created on 9/2/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
import Foundation
@testable import NimbusKit
@testable import NimbusLiveRampKit

// MARK: - LiveRamp.initialize

@Suite("Initialize tests")
struct InitializeTests {
    @Test func initializeThrowsIfNoIdentifierIsPassed() async throws {
        await #expect(throws: LiveRampError.missingIdentifier) {
            try await LiveRamp.initialize(placementId: "123", identifiers: [])
        }
    }
}

// MARK: - Base request

@Suite("Base request")
struct BaseRequestTests {

    @Test("Targets the envelope endpoint with GET")
    func endpointAndMethod() throws {
        let request = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")

        #expect(request.httpMethod == "GET")
        #expect(request.url?.host == "api.rlcdn.com")
        #expect(request.url?.path == "/api/identity/v2/envelope")
    }

    @Test("Sets the origin header to the https-prefixed bundle ID")
    func originHeader() throws {
        let request = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")

        #expect(request.value(forHTTPHeaderField: "origin") == "https://com.example.app")
        #expect(request.value(forHTTPHeaderField: "accept") == "application/json")
    }

    @Test("Carries the placement ID and implementation method")
    func requiredParameters() throws {
        let request = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")

        #expect(request.values(for: "pid") == ["14"])
        #expect(request.values(for: "atype") == ["2"])
    }

    @Test("Carries no identifier parameters")
    func noIdentifiers() throws {
        let request = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")

        #expect(request.values(for: "it").isEmpty)
        #expect(request.values(for: "iv").isEmpty)
    }

    @Test("gpp and gpp_sid are sent together or not at all")
    func gppIsPaired() throws {
        // Whichever way Nimbus is configured in the test host, a half GPP signal is
        // never valid: gpp_sid is what tells the API how to parse gpp.
        let request = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")

        #expect(request.values(for: "gpp").count == request.values(for: "gpp_sid").count)
    }
}

@Suite("Consent parameters", .serialized)
struct ConsentParameterTests {
 
    static let tcf = "CPUCbs9PUDXghADABCENCBCoAP_AAEJAAAAADGwBAAGABPADCAY0BjYAgADAAngBhAMaAAA.YAAAAAAAA4AA"
    static let gpp = "DBABLA~BVQqAAAAAAA"
 
    static let gppSectionId = "7"
    static let usPrivacy = "1YNN"
 
    init() {
        Self.clearConsent()
    }
 
    static func clearConsent() {
        Nimbus.IAB.tcfString = nil
        Nimbus.IAB.usPrivacyString = nil
        Nimbus.IAB.gppConsentString = nil
        Nimbus.IAB.gppSectionId = nil
    }
 
    private func request() throws -> URLRequest {
        try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")
    }
 
    @Test("No consent signals means no consent parameters")
    func noConsent() throws {
        defer { Self.clearConsent() }
 
        let request = try request()
 
        #expect(request.values(for: "ct").isEmpty)
        #expect(request.values(for: "cv").isEmpty)
        #expect(request.values(for: "gpp").isEmpty)
        #expect(request.values(for: "gpp_sid").isEmpty)
 
        // The placement parameters still go out; consent is additive.
        #expect(request.values(for: "pid") == ["14"])
        #expect(request.values(for: "atype") == ["2"])
    }
 
    @Test("A TCF string is sent as ct=4")
    func tcfString() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.tcfString = Self.tcf
 
        let request = try request()
 
        #expect(request.values(for: "ct") == ["4"])
        #expect(request.values(for: "cv") == [Self.tcf])
    }
 
    @Test("A US Privacy string is sent as ct=3")
    func usPrivacyString() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.usPrivacyString = Self.usPrivacy
 
        let request = try request()
 
        #expect(request.values(for: "ct") == ["3"])
        #expect(request.values(for: "cv") == [Self.usPrivacy])
    }
 
    @Test("TCF wins over US Privacy when both are present")
    func tcfTakesPrecedenceOverUsPrivacy() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.tcfString = Self.tcf
        Nimbus.IAB.usPrivacyString = Self.usPrivacy
 
        let request = try request()
 
        // ct and cv are single-valued, so the else-if must not emit both.
        #expect(request.values(for: "ct") == ["4"])
        #expect(request.values(for: "cv") == [Self.tcf])
    }
 
    @Test("GPP is sent when the string and section ID are both present")
    func gppPair() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.gppConsentString = Self.gpp
        Nimbus.IAB.gppSectionId = Self.gppSectionId
 
        let request = try request()
 
        #expect(request.values(for: "gpp") == [Self.gpp])
        #expect(request.values(for: "gpp_sid") == [Self.gppSectionId])
    }
 
    @Test("A GPP string without a section ID is not sent")
    func gppStringWithoutSectionId() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.gppConsentString = Self.gpp
 
        let request = try request()
 
        // gpp_sid is what tells the API how to parse gpp, so half a pair is
        // uninterpretable rather than merely incomplete — and an unparseable consent
        // string is a documented cause of a 451.
        #expect(request.values(for: "gpp").isEmpty)
        #expect(request.values(for: "gpp_sid").isEmpty)
    }
 
    @Test("A GPP section ID without a string is not sent")
    func gppSectionIdWithoutString() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.gppSectionId = Self.gppSectionId
 
        let request = try request()
 
        #expect(request.values(for: "gpp").isEmpty)
        #expect(request.values(for: "gpp_sid").isEmpty)
    }
 
    @Test("GPP and TCF are sent together")
    func gppAlongsideTcf() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.tcfString = Self.tcf
        Nimbus.IAB.gppConsentString = Self.gpp
        Nimbus.IAB.gppSectionId = Self.gppSectionId
 
        let request = try request()
 
        // Deliberate: the GPP block is independent of the ct/cv chain, so a user with
        // both signals sends both. LiveRamp documents them as alternatives but does
        // not forbid sending both.
        #expect(request.values(for: "gpp") == [Self.gpp])
        #expect(request.values(for: "gpp_sid") == [Self.gppSectionId])
        #expect(request.values(for: "ct") == ["4"])
        #expect(request.values(for: "cv") == [Self.tcf])
    }
 
    @Test("GPP and US Privacy are sent together")
    func gppAlongsideUsPrivacy() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.usPrivacyString = Self.usPrivacy
        Nimbus.IAB.gppConsentString = Self.gpp
        Nimbus.IAB.gppSectionId = Self.gppSectionId
 
        let request = try request()
 
        #expect(request.values(for: "gpp") == [Self.gpp])
        #expect(request.values(for: "ct") == ["3"])
        #expect(request.values(for: "cv") == [Self.usPrivacy])
    }
 
    @Test("Consent parameters survive onto the envelope request")
    func consentReachesEnvelopeRequest() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.tcfString = Self.tcf
        Nimbus.IAB.gppConsentString = Self.gpp
        Nimbus.IAB.gppSectionId = Self.gppSectionId
 
        let request = try LiveRamp.newEnvelopeRequest(
            from: try request(),
            identifiers: [.email("user@example.com")]
        )
 
        #expect(request.values(for: "ct") == ["4"])
        #expect(request.values(for: "cv") == [Self.tcf])
        #expect(request.values(for: "gpp") == [Self.gpp])
    }
 
    @Test("Consent parameters survive onto the refresh request")
    func consentReachesRefreshRequest() throws {
        defer { Self.clearConsent() }
        Nimbus.IAB.tcfString = Self.tcf
 
        let request = try LiveRamp.refreshRequest(from: try request(), storedResponse: Sample.response())
 
        // The refresh endpoint takes the same consent parameters, and the EU rule
        // applies to it too.
        #expect(request.url?.path == "/api/identity/v2/envelope/refresh")
        #expect(request.values(for: "ct") == ["4"])
        #expect(request.values(for: "cv") == [Self.tcf])
    }
 
    @Test("Consent is read at request time, not cached")
    func consentIsReadPerRequest() throws {
        defer { Self.clearConsent() }
 
        Nimbus.IAB.tcfString = Self.tcf
        #expect(try request().values(for: "cv") == [Self.tcf])
 
        // Matters for auto-refresh: a user can withdraw consent between the first
        // fetch and a later refresh, and the next request must reflect that.
        Nimbus.IAB.tcfString = nil
        #expect(try request().values(for: "ct").isEmpty)
        #expect(try request().values(for: "cv").isEmpty)
    }
}

// MARK: - New envelope request

@Suite("New envelope request")
struct NewEnvelopeRequestTests {

    let base: URLRequest

    init() throws {
        base = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")
    }

    @Test("Keeps the path, headers, and existing parameters")
    func preservesBaseRequest() throws {
        let request = try LiveRamp.newEnvelopeRequest(from: base, identifiers: [.phone("5551234567")])

        #expect(request.url?.path == "/api/identity/v2/envelope")
        #expect(request.value(forHTTPHeaderField: "origin") == "https://com.example.app")
        #expect(request.values(for: "pid") == ["14"])
        #expect(request.values(for: "atype") == ["2"])
    }

    @Test("Sends three hashed pairs for an email")
    func emailProducesThreeHashes() throws {
        let request = try LiveRamp.newEnvelopeRequest(from: base, identifiers: [.email("user@gmail.com")])

        #expect(request.values(for: "it") == ["4", "4", "4"])

        let values = request.values(for: "iv")
        #expect(values.count == 3)
        #expect(values.contains("user@gmail.com".hash(of: .sha256)))
        #expect(values.contains("user@gmail.com".hash(of: .sha1)))
        #expect(values.contains("user@gmail.com".hash(of: .md5)))
    }

    @Test("Normalizes the email before hashing")
    func normalizesBeforeHashing() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.email("  John.Doe+promo@GMAIL.com ")]
        )

        #expect(request.values(for: "iv").contains("johndoe@gmail.com".hash(of: .sha256)))
    }

    @Test("Never sends a raw email address")
    func neverSendsRawEmail() throws {
        let request = try LiveRamp.newEnvelopeRequest(from: base, identifiers: [.email("user@example.com")])
        let absolute = try #require(request.url?.absoluteString)

        #expect(absolute.contains("user@example.com") == false)
        #expect(absolute.contains("%40") == false)
    }

    @Test("Sends one SHA-1 pair for a phone")
    func phoneProducesOneHash() throws {
        let request = try LiveRamp.newEnvelopeRequest(from: base, identifiers: [.phone("+1 (555) 123-4567")])

        #expect(request.values(for: "it") == ["11"])
        #expect(request.values(for: "iv") == ["15551234567".hash(of: .sha1)])
    }

    @Test("Sends custom IDs unhashed as accountId:id")
    func customIdIsUnhashed() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.custom(accountId: "acct", id: "123")]
        )

        #expect(request.values(for: "it") == ["15"])
        #expect(request.values(for: "iv") == ["acct:123"])
    }

    @Test("Handles several identifiers in one request")
    func multipleIdentifiers() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.email("user@gmail.com"), .phone("5551234567")]
        )

        #expect(request.values(for: "it") == ["4", "4", "4", "11"])
        #expect(request.values(for: "iv").count == 4)
    }
    
    @Test("Refuses to build a request with no identifiers")
    func requiresIdentifiers() {
        #expect(throws: LiveRampError.self) {
            try LiveRamp.newEnvelopeRequest(from: base, identifiers: [])
        }
    }

    @Test("An invalid email alone produces no identifier parameters")
    func invalidEmailAlone() throws {
        let request = try LiveRamp.newEnvelopeRequest(from: base, identifiers: [.email("notanemail")])

        #expect(request.values(for: "it").isEmpty)
        #expect(request.values(for: "iv").isEmpty)
    }

    @Test("An invalid email does not stop a later identifier from being sent")
    func invalidEmailDoesNotBlockLaterIdentifiers() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.email("notanemail"), .phone("5551234567")]
        )

        #expect(request.values(for: "it") == ["11"])
        #expect(request.values(for: "iv") == ["5551234567".hash(of: .sha1)])
    }

    @Test("An invalid email does not stop an earlier identifier from being sent")
    func invalidEmailDoesNotDropEarlierIdentifiers() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.phone("5551234567"), .email("notanemail")]
        )

        #expect(request.values(for: "it") == ["11"])
        #expect(request.values(for: "iv") == ["5551234567".hash(of: .sha1)])
    }

    @Test("An invalid email does not stop a valid email from being sent")
    func invalidEmailDoesNotBlockValidEmail() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [.email("notanemail"), .email("user@gmail.com")]
        )

        #expect(request.values(for: "it") == ["4", "4", "4"])
        #expect(request.values(for: "iv").contains("user@gmail.com".hash(of: .sha256)))
    }

    @Test("Several invalid emails among valid identifiers only drop the invalid ones")
    func multipleInvalidEmailsAmongValidIdentifiers() throws {
        let request = try LiveRamp.newEnvelopeRequest(
            from: base,
            identifiers: [
                .email("notanemail"),
                .phone("5551234567"),
                .email("also not an email"),
                .custom(accountId: "acct", id: "123"),
            ]
        )

        #expect(request.values(for: "it") == ["11", "15"])
        #expect(request.values(for: "iv") == ["5551234567".hash(of: .sha1), "acct:123"])
    }
}

// MARK: - Refresh request

@Suite("Refresh request")
struct RefreshRequestTests {

    let base: URLRequest

    init() throws {
        base = try LiveRamp.prepareRequest(appId: "com.example.app", placementId: "14")
    }

    @Test("Appends /refresh to the path without disturbing the query")
    func pathAndQuery() throws {
        let request = try LiveRamp.refreshRequest(from: base, storedResponse: Sample.response())

        #expect(request.url?.path == "/api/identity/v2/envelope/refresh")
        #expect(request.values(for: "pid") == ["14"])
        #expect(request.values(for: "atype") == ["2"])
    }

    @Test("Keeps the headers from the base request")
    func headers() throws {
        let request = try LiveRamp.refreshRequest(from: base, storedResponse: Sample.response())

        #expect(request.value(forHTTPHeaderField: "origin") == "https://com.example.app")
        #expect(request.value(forHTTPHeaderField: "accept") == "application/json")
    }

    @Test("Sends the envelope type as it and the envelope as iv")
    func envelopeAsIdentifier() throws {
        let stored = Sample.response(envelopes: [Sample.envelope(19, value: "stored-value")])
        let request = try LiveRamp.refreshRequest(from: base, storedResponse: stored)

        #expect(request.values(for: "it") == ["19"])
        #expect(request.values(for: "iv") == ["stored-value"])
    }

    @Test("Includes only refreshable envelopes")
    func skipsNonRefreshable() throws {
        let stored = Sample.response(envelopes: [
            Sample.envelope(19, value: "ats"),
            Sample.envelope(24, value: "meta", source: "envelopeSource200"),
            Sample.envelope(25, value: "pair", source: "pairIds"),
            Sample.envelope(27, value: "ssp", source: "envelopeLiverampRTB"),
        ])

        let request = try LiveRamp.refreshRequest(from: base, storedResponse: stored)

        #expect(request.values(for: "it") == ["19", "24"])
        #expect(request.values(for: "iv") == ["ats", "meta"])
    }

    @Test("Emits no identifiers when nothing stored is refreshable")
    func noRefreshableEnvelopes() throws {
        let stored = Sample.response(envelopes: [Sample.envelope(25, value: "pair", source: "pairIds")])
        let request = try LiveRamp.refreshRequest(from: base, storedResponse: stored)

        #expect(request.values(for: "it").isEmpty)
        #expect(request.values(for: "iv").isEmpty)
    }

    @Test("Round-trips an envelope value containing base64 punctuation")
    func base64PunctuationSurvives() throws {
        // Slashes and equals signs have to come back out of the URL unchanged, or the
        // refresh is sent for a different envelope than the one stored.
        let value = "Aqs3wtOu/qIRic78+s4Nq=="
        let stored = Sample.response(envelopes: [Sample.envelope(19, value: value)])

        let request = try LiveRamp.refreshRequest(from: base, storedResponse: stored)
        #expect(request.values(for: "iv") == [value])
    }
}

// MARK: - Storage

/// These share `UserDefaults.standard`, so they run one at a time and clear the
/// key before and after each test.
@Suite("Storage", .serialized)
struct StorageTests {

    init() {
        LiveRamp.clear()
    }

    @Test("A stored envelope comes back with its timestamps intact")
    func storeAndLoad() throws {
        defer { LiveRamp.clear() }

        let created = Date(timeIntervalSince1970: 1_000_000)
        let stored = Sample.response(lastRefreshTime: created)

        LiveRamp.store(stored)
        let loaded = try #require(LiveRamp.getEnvelope())

        #expect(loaded.lastRefreshTime.timeIntervalSince1970 == created.timeIntervalSince1970)
        #expect(loaded.envelopes.count == stored.envelopes.count)
        #expect(loaded.envelopes[0].value == stored.envelopes[0].value)
    }

    @Test("Storing twice replaces rather than accumulates")
    func storeReplaces() throws {
        defer { LiveRamp.clear() }

        LiveRamp.store(Sample.response(envelopes: [Sample.envelope(19, value: "first")]))
        LiveRamp.store(Sample.response(envelopes: [Sample.envelope(19, value: "second")]))

        let loaded = try #require(LiveRamp.getEnvelope())
        #expect(loaded.envelopes.count == 1)
        #expect(loaded.envelopes[0].value == "second")
    }

    @Test("Nothing stored returns nil")
    func nothingStored() {
        #expect(LiveRamp.getEnvelope() == nil)
    }

    @Test("Corrupt stored data returns nil rather than throwing")
    func corruptData() {
        defer { LiveRamp.clear() }

        UserDefaults.standard.set(Data("garbage".utf8), forKey: LiveRamp.storedEnvelopeKey)
        #expect(LiveRamp.getEnvelope() == nil)
    }

    @Test("Clearing removes the stored envelope")
    func clear() {
        LiveRamp.store(Sample.response())
        #expect(LiveRamp.getEnvelope() != nil)

        LiveRamp.clear()
        #expect(LiveRamp.getEnvelope() == nil)
    }
}

// MARK: - Applying to Nimbus

/// These mutate `Nimbus.configuration.identity`, which is global, so they run one
/// at a time and reset it around each test.
@MainActor
@Suite("Applying to Nimbus", .serialized)
struct ApplyToNimbusTests {

    /// Base64 of `["pair-id-1"]`.
    static let onePairId = "WyJwYWlyLWlkLTEiXQ=="
    /// Base64 of `["pair-id-1","pair-id-2"]`.
    static let twoPairIds = "WyJwYWlyLWlkLTEiLCJwYWlyLWlkLTIiXQ=="
    /// Base64 of `[]`.
    static let noPairIds = "W10="
    /// Base64 of `{"not":"an array"}` — decodes fine, but isn't `[String]`.
    static let pairObject = "eyJub3QiOiJhbiBhcnJheSJ9"

    init() {
        Nimbus.configuration.identity.clear()
    }

    @Test("An ATS envelope registers under liveramp.com")
    func atsEnvelope() throws {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [Sample.envelope(19, value: "ats-envelope")]).applyToNimbus()

        let eid = try #require(Nimbus.configuration.identity.extendedIds["liveramp.com"])
        #expect(eid.source == "liveramp.com")
        #expect(eid.uids.count == 1)

        let uid = try #require(eid.uids.first)
        #expect(uid.id == "ats-envelope")
        #expect(uid.ext["rtiPartner"] == "idl")
    }

    @Test("A PAIR envelope registers its decoded IDs under google.com")
    func pairEnvelope() throws {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [
            Sample.envelope(25, value: Self.onePairId, source: "pairIds")
        ]).applyToNimbus()

        let eid = try #require(Nimbus.configuration.identity.extendedIds["google.com"])
        #expect(eid.uids.count == 1)

        let uid = try #require(eid.uids.first)
        #expect(uid.id == "pair-id-1")
        #expect(uid.atype == 571187)
    }

    @Test("A PAIR envelope carrying several IDs registers all of them")
    func pairEnvelopeWithMultipleIds() throws {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [
            Sample.envelope(25, value: Self.twoPairIds, source: "pairIds")
        ]).applyToNimbus()

        let eid = try #require(Nimbus.configuration.identity.extendedIds["google.com"])
        #expect(Set(eid.uids.map(\.id)) == ["pair-id-1", "pair-id-2"])
    }

    @Test("ATS and PAIR envelopes register under separate sources")
    func atsAndPairTogether() throws {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [
            Sample.envelope(19, value: "ats-envelope"),
            Sample.envelope(25, value: Self.onePairId, source: "pairIds"),
        ]).applyToNimbus()

        #expect(Nimbus.configuration.identity.extendedIds["liveramp.com"]?.uids.count == 1)
        #expect(Nimbus.configuration.identity.extendedIds["google.com"]?.uids.count == 1)
    }

    @Test("The documented sample payload applies both envelopes")
    func documentedSamplePayload() throws {
        defer { Nimbus.configuration.identity.clear() }

        let response = try JSONDecoder().decode(
            LiveRamp.EnvelopeResponse.self,
            from: Data(Sample.envelopeJSON.utf8)
        )
        response.applyToNimbus()

        #expect(Nimbus.configuration.identity.extendedIds["liveramp.com"] != nil)

        let pair = try #require(Nimbus.configuration.identity.extendedIds["google.com"])
        #expect(pair.uids.map(\.id) == ["AyXb5Atvk/U/1CWvz2nEY9hYxOX7MQOQ2UBMA0WbWVEm"])
    }

    @Test("Unhandled envelope types register nothing", arguments: [24, 26, 27, 99])
    func unhandledTypes(rawType: Int) {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [Sample.envelope(rawType, value: "value")]).applyToNimbus()

        #expect(Nimbus.configuration.identity.extendedIds.isEmpty)
    }

    @Test("An empty envelope list registers nothing")
    func emptyEnvelopes() {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: []).applyToNimbus()

        #expect(Nimbus.configuration.identity.extendedIds.isEmpty)
    }

    @Test("A PAIR value that isn't decodable registers nothing", arguments: [
        "not base64 at all!",
        pairObject,
        noPairIds,
    ])
    func undecodablePairValues(value: String) {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [Sample.envelope(25, value: value, source: "pairIds")]).applyToNimbus()

        // An empty array still produces an EID with no UIDs rather than nothing at
        // all, so assert on the UID count rather than on the source being absent.
        #expect(Nimbus.configuration.identity.extendedIds["google.com"]?.uids.isEmpty ?? true)
    }

    @Test("A bad PAIR envelope does not stop a good ATS envelope from applying")
    func oneBadEnvelopeDoesNotBlockTheRest() {
        defer { Nimbus.configuration.identity.clear() }

        Sample.response(envelopes: [
            Sample.envelope(25, value: "not base64 at all!", source: "pairIds"),
            Sample.envelope(19, value: "ats-envelope"),
        ]).applyToNimbus()

        #expect(Nimbus.configuration.identity.extendedIds["liveramp.com"]?.uids.count == 1)
    }

    @Test("Two envelopes of the same type: the last one wins")
    func sameSourceOverwrites() throws {
        defer { Nimbus.configuration.identity.clear() }

        // add(source:ids:) assigns extendedIds[source] rather than merging, so a
        // response carrying two ATS envelopes keeps only the second.
        Sample.response(envelopes: [
            Sample.envelope(19, value: "first"),
            Sample.envelope(19, value: "second"),
        ]).applyToNimbus()

        let eid = try #require(Nimbus.configuration.identity.extendedIds["liveramp.com"])
        #expect(eid.uids.count == 1)
        #expect(eid.uids.first?.id == "second")
    }
}
