//
//  LiveRampExtension.swift
//  NimbusLiveRampKit
//  Created on 9/9/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit


struct LiveRampExtension: NimbusRequestExtension {
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public let interceptor: any NimbusRequest.Interceptor
    
    func coppaDidChange(coppa: Bool) {
        // No-op
    }
    
    init() {
        self.interceptor = LiveRampInterceptor()
    }
}

final class LiveRampInterceptor: NimbusRequest.Interceptor {
    func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        Task.detached {
            try await LiveRamp.updateEnvelope()
        }
        
        return []
    }
}
