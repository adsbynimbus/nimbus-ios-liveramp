//
//  HelperTests.swift
//  NimbusLiveRampKit
//  Created on 9/9/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusLiveRampKit
import Foundation

// MARK: - Query building

@Suite("Query building")
struct QueryBuildingTests {

    @Test("Inserts identifiers onto a URL with no existing query")
    func insertsOntoEmptyQuery() {
        var components = URLComponents(string: "https://example.com/path")!
        #expect(components.queryItems == nil)

        components.insert(identifiers: [.phone("5551234567")])
        #expect(components.queryItems?.count == 2)
    }

    @Test("Preserves pre-existing query items")
    func preservesExisting() {
        var components = URLComponents(string: "https://example.com?pid=14&atype=2")!
        components.insert(identifiers: [.phone("5551234567")])

        #expect(components.queryItems?.filter { $0.name == "pid" }.compactMap(\.value) == ["14"])
        #expect(components.queryItems?.filter { $0.name == "atype" }.compactMap(\.value) == ["2"])
    }

    @Test("Inserts envelopes onto a URL with no existing query")
    func insertsEnvelopesOntoEmptyQuery() {
        var components = URLComponents(string: "https://example.com/path")!
        components.insert(envelopeResponse: Sample.response())

        #expect(components.queryItems?.count == 2)
    }
}

// MARK: - Normalization

@Suite("Email normalization")
struct EmailNormalizationTests {

    @Test("Trims whitespace and lowercases")
    func trimsAndLowercases() {
        #expect(Sample.components.normalize(email: "  User@Example.COM  ") == "user@example.com")
    }

    @Test("Strips the plus tag")
    func stripsPlusTag() {
        #expect(Sample.components.normalize(email: "user+newsletter@example.com") == "user@example.com")
    }

    @Test("Removes dots only for Gmail")
    func removesGmailDots() {
        #expect(Sample.components.normalize(email: "john.doe@gmail.com") == "johndoe@gmail.com")
        #expect(Sample.components.normalize(email: "john.doe@example.com") == "john.doe@example.com")
    }

    @Test("Applies plus-stripping and dot-removal together")
    func combinedGmailRules() {
        #expect(Sample.components.normalize(email: "John.Doe+promo@GMAIL.com") == "johndoe@gmail.com")
    }

    @Test("Returns nil for malformed input rather than passing it through")
    func malformedInputReturnsNil() {
        #expect(Sample.components.normalize(email: " NotAnEmail ") == nil)
        #expect(Sample.components.normalize(email: "a@b@c") == nil)
    }

    @Test("Returns nil for malformed addresses", arguments: [
        "",
        " ",
        "notanemail",
        "user@",
        "@example.com",
        "@",
        "user example.com",
        "user@@example.com",
    ])
    func returnsNilForMalformed(_ input: String) {
        #expect(Sample.components.normalize(email: input) == nil)
    }

    @Test("Returns nil for non-mailto links", arguments: [
        "apple.com",
        "www.apple.com",
        "https://example.com",
        "tel:+15551234567",
    ])
    func returnsNilForNonMailtoLinks(_ input: String) {
        #expect(Sample.components.normalize(email: input) == nil)
    }

    @Test("Returns nil for addresses embedded in surrounding text", arguments: [
        "hello user@example.com please",
        "email me at user@example.com",
        "<user@example.com>",
        "(user@example.com)",
    ])
    func returnsNilForEmbeddedAddresses(_ input: String) {
        #expect(Sample.components.normalize(email: input) == nil)
    }

    @Test("Returns nil for input containing more than one address", arguments: [
        "one@example.com two@example.com",
        "one@example.com, two@example.com",
    ])
    func returnsNilForMultipleMatches(_ input: String) {
        #expect(Sample.components.normalize(email: input) == nil)
    }

    @Test("Returns nil for header injection attempts", arguments: [
        "user@example.com\nBcc: attacker@evil.com",
        "user@example.com%0ABcc:attacker@evil.com",
        "user@example.com\r\nSubject: spam",
    ])
    func returnsNilForInjectionAttempts(_ input: String) {
        #expect(Sample.components.normalize(email: input) == nil)
    }

    @Test("Still normalizes and validates every accepted address shape", arguments: [
        "user@example.com",
        "first.last@example.com",
        "first.last@example.co.uk",
        "user+tag@example.com",
        "user_name@example.com",
        "user-name@example.com",
        "123@example.com",
        "u@example.com",
        "user@subdomain.example.com",
        "USER@EXAMPLE.COM",
    ])
    func stillNormalizesValidShapes(_ address: String) {
        #expect(Sample.components.normalize(email: address) != nil)
    }

    @Test("Normalizing an already-normalized email changes nothing", arguments: [
        "User+tag@Gmail.com",
        "  plain@example.com  ",
        "a.b.c@gmail.com",
    ])
    func normalizingTwiceMatchesOnce(input: String) {
        let once = Sample.components.normalize(email: input)!
        #expect(Sample.components.normalize(email: once) == once)
    }
    
    @Test("Accepts common address shapes", arguments: [
        "user@example.com",
        "first.last@example.com",
        "first.last@example.co.uk",
        "user+tag@example.com",
        "user_name@example.com",
        "user-name@example.com",
        "123@example.com",
        "u@example.com",
        "user@subdomain.example.com",
        "USER@EXAMPLE.COM",
    ])
    func acceptsValidAddresses(_ address: String) {
        #expect(address.isValidEmail)
    }

    @Test("Rejects malformed addresses", arguments: [
        "",
        " ",
        "notanemail",
        "user@",
        "@example.com",
        "@",
        "user example.com",
        "user@ example.com",
        "user @example.com",
        "user@@example.com",
    ])
    func rejectsMalformed(_ address: String) {
        #expect(!address.isValidEmail)
    }

    @Test("Rejects non-mailto links", arguments: [
        "apple.com",
        "www.apple.com",
        "https://example.com",
        "http://example.com/user@example.com",
        "tel:+15551234567",
        "ftp://example.com",
    ])
    func rejectsNonMailtoLinks(_ input: String) {
        #expect(!input.isValidEmail)
    }

    @Test("Rejects addresses embedded in surrounding text", arguments: [
        "hello user@example.com please",
        "user@example.com please",
        "email me at user@example.com",
        "user@example.com.",
        "<user@example.com>",
        "(user@example.com)",
        "\"user@example.com\"",
    ])
    func rejectsEmbeddedAddresses(_ input: String) {
        #expect(!input.isValidEmail)
    }

    @Test("Rejects surrounding whitespace and newlines", arguments: [
        " user@example.com",
        "user@example.com ",
        "  user@example.com  ",
        "\tuser@example.com",
        "user@example.com\n",
        "user@example.com\nsecond line",
    ])
    func rejectsUntrimmedInput(_ input: String) {
        #expect(!input.isValidEmail)
    }

    @Test("Rejects input containing more than one address", arguments: [
        "one@example.com two@example.com",
        "one@example.com, two@example.com",
        "one@example.com apple.com",
    ])
    func rejectsMultipleMatches(_ input: String) {
        #expect(!input.isValidEmail)
    }

    @Test("Rejects header injection attempts", arguments: [
        "user@example.com\nBcc: attacker@evil.com",
        "user@example.com%0ABcc:attacker@evil.com",
        "user@example.com\r\nSubject: spam",
    ])
    func rejectsInjectionAttempts(_ input: String) {
        #expect(!input.isValidEmail)
    }
}

@Suite("Phone normalization")
struct PhoneNormalizationTests {

    @Test("Strips formatting characters")
    func stripsFormatting() {
        #expect(Sample.components.normalize(phone: "+1 (555) 123-4567") == "15551234567")
    }

    @Test("Strips leading zeros")
    func stripsLeadingZeros() {
        #expect(Sample.components.normalize(phone: "0044 7700 900123") == "447700900123")
    }

    @Test("Keeps a single zero rather than emptying the string")
    func keepsLoneZero() {
        #expect(Sample.components.normalize(phone: "0") == "0")
        #expect(Sample.components.normalize(phone: "000") == "0")
    }

    @Test("Returns empty for input with no digits")
    func noDigits() {
        #expect(Sample.components.normalize(phone: "not a phone") == "")
    }
}

// MARK: - Hashing

@Suite("Hashing")
struct HashingTests {

    @Test("Produces known digests")
    func knownVectors() {
        #expect("user@gmail.com".hash(of: .sha256) == "02ee7bdc4ccf5c94808a0118eb531822f13e7e38e3810ab29ebefb2c2feb8e58")
        #expect("user@gmail.com".hash(of: .sha1) == "5a4cd0167fd2730dae4430fd5aaa4c79a89c18d4")
        #expect("user@gmail.com".hash(of: .md5) == "cba1f2d695a5ca39ee6f343297a761a4")
        #expect("15551234567".hash(of: .sha1) == "c9ae73c7e7ce775a5b8152f332e6a913bc1fe2b4")
    }

    @Test("Batch hashing matches individual hashing and preserves order")
    func batchMatchesIndividual() {
        let digests = "user@gmail.com".hash(of: [.sha256, .sha1, .md5])
        #expect(digests == [
            "user@gmail.com".hash(of: .sha256),
            "user@gmail.com".hash(of: .sha1),
            "user@gmail.com".hash(of: .md5),
        ])
    }

    @Test("Digests are lowercase hex of the expected length")
    func digestFormat() {
        #expect("x".hash(of: .sha256).count == 64)
        #expect("x".hash(of: .sha1).count == 40)
        #expect("x".hash(of: .md5).count == 32)
        #expect("x".hash(of: .sha256).allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test("Hashes UTF-8 bytes")
    func nonASCII() {
        let expected = HashType.sha256.hash(of: Data("café@example.com".utf8))
        #expect("café@example.com".hash(of: .sha256) == expected)
    }
}
