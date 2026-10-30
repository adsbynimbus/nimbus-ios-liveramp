Pod::Spec.new do |spec|
    spec.name                   = 'NimbusLiveRampKit'
    spec.version                = '0.0.1-development'
    spec.summary                = 'Nimbus LiveRamp wrapper'
    spec.homepage               = 'https://www.adsbynimbus.com'
    spec.social_media_url       = 'https://twitter.com/adsbynimbus'
    spec.author                 = 'Nimbus'
    spec.platform               = :ios, '15.0'
    spec.documentation_url      = 'https://docs.adsbynimbus.com/docs'
    spec.license                = { :type => 'Apache-2.0', :file => 'LICENSE' }
    spec.swift_versions         = ['5', '6']
    spec.ios.deployment_target  = '15.0'
    spec.static_framework       = true
    spec.source_files           = "Sources/NimbusLiveRampKit/**/*.swift"
    spec.source                 = {
        :git => "https://github.com/adsbynimbus/nimbus-ios-liveramp.git", 
        :tag => spec.version.to_s
    }

    spec.dependency 'NimbusSDK/NimbusKit', '~> 3'
end
