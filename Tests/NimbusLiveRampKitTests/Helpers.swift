//
//  Helpers.swift
//  NimbusLiveRampKit
//  Created on 9/2/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
@testable import NimbusLiveRampKit

enum Sample {
    /// The sample payload from LiveRamp's mobile implementation guide.
    static let envelopeJSON = """
    {"envelopes":[\
    {"type":19,"source":"envelopeLiveramp","value":"Aqs3wtOuqIRic78_s4Nqilcr0MGn0cDv","err":null},\
    {"type":25,"source":"pairIds","value":"WyJBeVhiNUF0dmsvVS8xQ1d2ejJuRVk5aFl4T1g3TVFPUTJVQk1BMFdiV1ZFbSJd","err":null}\
    ]}
    """

    static func envelope(
        _ rawType: Int,
        value: String,
        source: String = "envelopeLiveramp"
    ) -> LiveRamp.Envelope {
        .init(rawType: rawType, source: source, value: value, err: nil)
    }

    static func response(
        envelopes: [LiveRamp.Envelope] = [envelope(19, value: "abc")],
        lastRefreshTime: Date = Date()
    ) -> LiveRamp.EnvelopeResponse {
        .init(envelopes: envelopes, lastRefreshTime: lastRefreshTime)
    }

    /// The normalize methods are instance members on URLComponents, so tests need
    /// some instance to call them on.
    static let components = URLComponents(string: "https://example.com")!
}

extension URLRequest {
    var queryItems: [URLQueryItem] {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [] }
        return components.queryItems ?? []
    }

    func values(for name: String) -> [String] {
        queryItems.filter { $0.name == name }.compactMap(\.value)
    }
}
