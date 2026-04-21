//
//  LREnvelope+Nimbus.swift
//  Nimbus
//  Created on 3/17/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import LRAtsSDK
import NimbusKit

extension LREnvelope {
    /// Decodes Pair IDs from LiveRamp envelope
    var pairIds: [String]? {
        guard let envelope25, let decodedPair = Data(base64Encoded: envelope25),
              let pairIds = try? JSONSerialization.jsonObject(with: decodedPair) as? [String]
        else { return nil }
        
        return pairIds
    }
    
    /// Applies LiveRamp envelope to Nimbus as EID. This method also applies google pair ID if available.
    @MainActor
    public func applyToNimbus() {
        if let unwrappedEnvelope = envelope {
            Nimbus.EID.set(
                .init(
                    source: "liveramp.com",
                    uids: [.init(id: unwrappedEnvelope, extensions: ["rtiPartner": "idl"])]
                )
            )
        }
        
        if let pairIds = pairIds {
            Nimbus.EID.set(
                .init(
                    source: "google.com",
                    uids: pairIds.map { .init(id: $0, atype: 571187) }
                )
            )
        }
    }
}
