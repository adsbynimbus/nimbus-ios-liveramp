//
//  NimbusLiveRampKitTests.swift
//  NimbusLiveRampKitTests
//
//  Created on 20/07/22.
//  Copyright © 2022 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusLiveRampKit
@testable import NimbusKit

import LRAtsSDK
import Testing

@MainActor
@Suite("NimbusLiveRamp tests", .serialized) struct NimbusLiveRampTests {
    
    let configId = "012345"
    let email = "test@email.com"
    let phoneNumber = "15005550000"
    
    @Test("init with email sets all EIDs")
    func initWithEmail() async throws {
        let liveRamp = LiveRamp(configId: configId, email: email)
        
        #expect(liveRamp.email == email)
        #expect(liveRamp.phoneNumber == nil)
        
        try await assertFetchEnvelope(using: liveRamp)
    }
    
    @Test("init with phone number sets all EIDs")
    func initWithPhoneNumber() async throws {
        let liveRamp = LiveRamp(configId: configId, phoneNumber: phoneNumber)
        
        #expect(liveRamp.phoneNumber == phoneNumber)
        #expect(liveRamp.email == nil)
        
        try await assertFetchEnvelope(using: liveRamp)
    }
    
    @Test("consent gets set")
    func consentGetsSet() async throws {
        LRAts.shared.hasConsentForNoLegislation = false
        
        #expect(LRAts.shared.hasConsentForNoLegislation == false)
        
        let _ = LiveRamp(configId: configId, email: email, hasConsentForNoLegislation: true)
        
        #expect(LRAts.shared.hasConsentForNoLegislation == true)
    }
    
    @Test("LiveRamp EIDs get added to the request")
    func liveRampEIDsGetAddedToTheRequest() async throws {
        let liveRamp = LiveRamp(configId: configId, email: email)
        
        try await assertFetchEnvelope(using: liveRamp)
        
        let ad = Nimbus.bannerAd(position: "position", size: .banner)
        try await ad.adRequest!.request.modifyRequestWithExtras(
            configuration: Nimbus.configuration,
            vendorId: "",
            appVersion: "1.0.0"
        )
        
        let eids = ad.adRequest!.request.user?.ext?.eids
        
        #expect(eids != nil)
        
        let liveRampEID = eids?.first(where: { $0.source == "liveramp.com" })
        
        #expect(liveRampEID != nil)
        #expect(liveRampEID?.uids.first?.ext["rtiPartner"] == "idl")
        
        let pairEID = eids?.first(where: { $0.source == "google.com" })
        #expect(pairEID != nil)
        #expect(pairEID?.uids.first?.atype == 571187)
    }
    
    private func assertFetchEnvelope(using: LiveRamp, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let envelope = try await using.fetchEnvelope(isTestMode: true)
        envelope.applyToNimbus()
        
        let liveRampExtendedId = Nimbus.configuration.identity.extendedIds["liveramp.com"]

        #expect(liveRampExtendedId?.source == "liveramp.com", sourceLocation: sourceLocation)
        #expect(liveRampExtendedId?.uids.count == 1, sourceLocation: sourceLocation)
        #expect(liveRampExtendedId?.uids.contains { $0.id == envelope.envelope! && $0.ext == ["rtiPartner": "idl"] } == true, sourceLocation: sourceLocation)

        let liveRampPairIds = Nimbus.configuration.identity.extendedIds["google.com"]
        let expectedUids = Set(envelope.pairIds!.map { RTB.UID(id: $0, atype: 571187) })

        #expect(liveRampPairIds?.source == "google.com", sourceLocation: sourceLocation)
        #expect(liveRampPairIds?.uids == expectedUids, sourceLocation: sourceLocation)
    }
}
