//
//  EnvelopeResponseTests.swift
//  NimbusLiveRampKit
//  Created on 9/3/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusLiveRampKit
import Foundation
import Testing

@Suite("Envelope decoding")
struct EnvelopeDecodingTests {

    @Test("Decodes LiveRamp's documented sample payload")
    func decodesSample() throws {
        let response = try JSONDecoder().decode(
            LiveRamp.EnvelopeResponse.self,
            from: Data(Sample.envelopeJSON.utf8)
        )

        #expect(response.envelopes.count == 2)
        #expect(response.envelopes[0].type == .ats)
        #expect(response.envelopes[0].source == "envelopeLiveramp")
        #expect(response.envelopes[1].type == .googlePair)
        #expect(response.envelopes[0].err == nil)
    }

    @Test("Unknown envelope types decode to nil without dropping the envelope")
    func unknownTypeSurvives() throws {
        let json = #"{"envelopes":[{"type":99,"source":"future","value":"v","err":null}]}"#
        let response = try JSONDecoder().decode(LiveRamp.EnvelopeResponse.self, from: Data(json.utf8))

        #expect(response.envelopes.count == 1)
        #expect(response.envelopes[0].type == nil)
        #expect(response.envelopes[0].rawType == 99)
        #expect(response.envelopes[0].isRefreshable == false)
    }

    @Test("Decodes an empty envelope list")
    func emptyEnvelopes() throws {
        let response = try JSONDecoder().decode(
            LiveRamp.EnvelopeResponse.self,
            from: Data(#"{"envelopes":[]}"#.utf8)
        )
        #expect(response.envelopes.isEmpty)
    }

    @Test("Surfaces a per-envelope error string")
    func envelopeError() throws {
        let json = #"{"envelopes":[{"type":19,"source":"envelopeLiveramp","value":"","err":"bad request"}]}"#
        let response = try JSONDecoder().decode(LiveRamp.EnvelopeResponse.self, from: Data(json.utf8))
        #expect(response.envelopes[0].err == "bad request")
    }

    @Test("A server response with no timestamps defaults them to now")
    func defaultsTimestamps() throws {
        let before = Date()
        let response = try JSONDecoder().decode(
            LiveRamp.EnvelopeResponse.self,
            from: Data(Sample.envelopeJSON.utf8)
        )

        #expect(response.lastRefreshTime >= before)
    }

    @Test("Round-tripping preserves the timestamps")
    func roundTripPreservesTimestamps() throws {
        // Regression: with createdAt outside CodingKeys, decoding reset it to now, so
        // the TTL check could never fail and stored envelopes never expired.
        let refreshed = Date(timeIntervalSince1970: 2_000_000)
        let original = Sample.response(lastRefreshTime: refreshed)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LiveRamp.EnvelopeResponse.self, from: data)

        #expect(decoded.lastRefreshTime.timeIntervalSince1970 == refreshed.timeIntervalSince1970)
    }

    @Test("isRefreshable covers exactly ATS and Meta", arguments: [
        (19, true), (24, true), (25, false), (26, false), (27, false), (99, false),
    ])
    func refreshability(rawType: Int, expected: Bool) {
        #expect(Sample.envelope(rawType, value: "v").isRefreshable == expected)
    }
    
    @Test("A single bad envelope doesn't break the whole response decoding")
    func oneBadEnvelopeDoesntBreakDecoding() throws {
        let envelopeJSON = """
        {"envelopes":[\
        {"type":19,"err":"invalid envelope"},\
        {"type":25,"source":"pairIds","value":"WyJBeVhiNUF0dmsvVS8xQ1d2ejJuRVk5aFl4T1g3TVFPUTJVQk1BMFdiV1ZFbSJd","err":null}\
        ]}
        """
        
        let response = try JSONDecoder().decode(
            LiveRamp.EnvelopeResponse.self,
            from: envelopeJSON.data(using: .utf8)!
        )
        
        #expect(response.envelopes.count == 1)
        #expect(response.envelopes[0].type == .googlePair)
    }
}
