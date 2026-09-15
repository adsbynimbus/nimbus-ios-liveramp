//
//  EnvelopeResponse.swift
//  NimbusLiveRampKit
//  Created on 9/2/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit

extension LiveRamp {
    enum EnvelopeType: Int {
        case ats = 19
        case meta = 24
        case googlePair = 25
        case atsDirect = 26
        case googleSSP = 27
    }

    /// A decoded response from the ATS Envelope API.
    ///
    /// - Note: `createdAt` and `lastRefreshTime` are local. The server sends neither;
    ///   they are supplied when the response is stored so the expiry and refresh
    ///   checks survive a relaunch.
    public struct EnvelopeResponse: Codable, Sendable {
        
        private struct DummyDecodable: Decodable {}
        
        /// Every envelope returned, including types this SDK does not act on.
        public let envelopes: [Envelope]

        /// The date this envelope was last refreshed.
        public internal(set) var lastRefreshTime: Date

        enum CodingKeys: String, CodingKey {
            case envelopes
            case lastRefreshTime
        }

        init(envelopes: [Envelope], lastRefreshTime: Date = Date()) {
            self.envelopes = envelopes
            self.lastRefreshTime = lastRefreshTime
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            /// Skip envelopes that fail decoding but avoid failing the entire EnvelopeResponse decoding
            var envelopesContainer = try container.nestedUnkeyedContainer(forKey: .envelopes)
            var okEnvelopes: [Envelope] = []
            
            while !envelopesContainer.isAtEnd {
                do {
                    okEnvelopes.append(try envelopesContainer.decode(Envelope.self))
                } catch {
                    _ = try? envelopesContainer.decode(DummyDecodable.self)
                }
            }
            
            envelopes = okEnvelopes

            // Absent in a server response, present when read back from storage.
            lastRefreshTime = try container.decodeIfPresent(Date.self, forKey: .lastRefreshTime) ?? Date()
        }

        @MainActor
        func applyToNimbus() {
            for envelope in envelopes {
                switch envelope.type {
                case .ats:
                    Nimbus.configuration.identity.add(
                        source: "liveramp.com",
                        ids: [.init(id: envelope.value, extensions: ["rtiPartner": "idl"])]
                    )
                case .googlePair:
                    // A PAIR value is a base64-encoded JSON array, not a single ID.
                    if let decodedPair = Data(base64Encoded: envelope.value),
                       let pairIds = try? JSONSerialization.jsonObject(with: decodedPair) as? [String] {
                        Nimbus.configuration.identity.add(
                            source: "google.com",
                            ids: Set(pairIds.map { .init(id: $0, atype: 571187) })
                        )
                    }

                default: break
                }
            }
        }
    }

    /// A single identity envelope.
    public struct Envelope: Codable, Sendable {
        /// The raw `type` value, kept as an `Int` so unknown types survive a round trip.
        public let rawType: Int

        /// The envelope source, such as `envelopeLiveramp` or `pairIds`.
        public let source: String

        /// The envelope itself, as passed into the bidstream.
        public let value: String

        /// A per-envelope error reported by the API, if any.
        public let err: String?

        enum CodingKeys: String, CodingKey {
            case rawType = "type"
            case source
            case value
            case err
        }

        init(rawType: Int, source: String, value: String, err: String? = nil) {
            self.rawType = rawType
            self.source = source
            self.value = value
            self.err = err
        }

        var type: EnvelopeType? { EnvelopeType(rawValue: rawType) }

        var isRefreshable: Bool {
            switch type {
            case .ats, .meta: true
            default: false
            }
        }
    }
}
