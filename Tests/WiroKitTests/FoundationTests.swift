import Foundation
import Testing
@testable import WiroKit

@Suite("WiroJSONValue")
struct WiroJSONValueTests {
    @Test("dictionary literals compile with mixed value types")
    func dictionaryLiterals() {
        let json: WiroJSON = [
            "prompt": "x",
            "seed": 42,
            "flag": true,
            "ratio": 1.5,
            "tags": ["a", "b"],
            "nested": ["k": "v"],
            "empty": nil,
        ]

        #expect(json["prompt"]?.stringValue == "x")
        #expect(json["seed"]?.intValue == 42)
        #expect(json["flag"]?.boolValue == true)
        #expect(json["ratio"]?.doubleValue == 1.5)
        #expect(json["tags"]?.arrayValue?.count == 2)
        #expect(json["nested"]?.objectValue?["k"]?.stringValue == "v")
        #expect(json["empty"]?.isNull == true)
    }

    @Test("Codable round-trip preserves structure")
    func codableRoundTrip() throws {
        let original: WiroJSONValue = [
            "prompt": "hello",
            "seed": 42,
            "flag": true,
            "items": [1, "two", false, nil],
            "nested": ["a": 1.25],
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder()
            .decode(WiroJSONValue.self, from: data)
        #expect(decoded == original)
    }

    @Test("toAny and fromAny round-trip")
    func anyRoundTrip() throws {
        let original: WiroJSONValue = [
            "name": "wiro",
            "count": 3,
            "ok": true,
            "list": [1, 2],
            "missing": nil,
        ]

        let any = original.toAny()
        let data = try JSONSerialization.data(
            withJSONObject: any,
            options: []
        )
        let reloaded = try JSONSerialization.jsonObject(
            with: data,
            options: []
        )
        let restored = try #require(WiroJSONValue.fromAny(reloaded))
        #expect(restored == original)
    }

    @Test("accessors return nil for mismatched types")
    func mismatchedAccessors() {
        let value: WiroJSONValue = "text"
        #expect(value.intValue == nil)
        #expect(value.boolValue == nil)
        #expect(value.objectValue == nil)
        #expect(value.arrayValue == nil)
        #expect(value.stringValue == "text")
        #expect(value.isNull == false)

        let number: WiroJSONValue = 3
        #expect(number.stringValue == nil)
        #expect(number.doubleValue == 3)

        #expect(WiroJSONValue.null.isNull == true)
        #expect(WiroJSONValue.bool(true).doubleValue == nil)
        #expect(WiroJSONValue.string("nope").doubleValue == nil)
    }

    @Test("intValue coerces numeric strings")
    func intValueFromString() {
        #expect(WiroJSONValue.string("42").intValue == 42)
        #expect(WiroJSONValue.string(" 7 ").intValue == 7)
        #expect(WiroJSONValue.string("nope").intValue == nil)
        #expect(WiroJSONValue.number(3.5).intValue == nil)
        #expect(WiroJSONValue.bool(true).intValue == nil)
    }

    @Test("Codable decode covers null and rejects unsupported")
    func codableEdgeCases() throws {
        let nullData = Data("null".utf8)
        let decodedNull = try JSONDecoder()
            .decode(WiroJSONValue.self, from: nullData)
        #expect(decodedNull == .null)

        // Decode representative scalar and collection values.
        #expect(
            try JSONDecoder()
                .decode(WiroJSONValue.self, from: Data("true".utf8))
                == .bool(true)
        )
        #expect(
            try JSONDecoder()
                .decode(WiroJSONValue.self, from: Data("1.5".utf8))
                == .number(1.5)
        )
        #expect(
            try JSONDecoder()
                .decode(WiroJSONValue.self, from: Data(#""hi""#.utf8))
                == .string("hi")
        )
        #expect(
            try JSONDecoder()
                .decode(WiroJSONValue.self, from: Data("[]".utf8))
                == .array([])
        )
    }
}

@Suite("JSONReader")
struct JSONReaderTests {
    @Test("integer parses numbers and numeric strings")
    func integerLeniency() {
        #expect(JSONReader.integer(.number(42)) == 42)
        #expect(JSONReader.integer(.string("42")) == 42)
        #expect(JSONReader.integer(.string(" 99 ")) == 99)
        #expect(JSONReader.integer(.string("x")) == nil)
        #expect(JSONReader.integer(.bool(true)) == nil)
        #expect(JSONReader.integer(.number(3.5)) == nil)
        #expect(JSONReader.integer(.number(.infinity)) == nil)

        let object: WiroJSON = ["n": "7", "m": 8]
        #expect(JSONReader.integer(object, "n") == 7)
        #expect(JSONReader.integer(object, "m") == 8)
        #expect(JSONReader.integer(object, "missing") == nil)
    }

    @Test("double parses numbers and numeric strings")
    func doubleLeniency() {
        #expect(JSONReader.double(.number(3.14)) == 3.14)
        #expect(JSONReader.double(.string("2.5")) == 2.5)
        #expect(JSONReader.double(.string("bad")) == nil)
        #expect(JSONReader.double(.number(.nan)) == nil)
        #expect(JSONReader.double(.bool(true)) == nil)

        let object: WiroJSON = ["d": "1.25"]
        #expect(JSONReader.double(object, "d") == 1.25)
    }

    @Test("boolean parses bool, strings, and 0/1")
    func booleanLeniency() {
        #expect(JSONReader.boolean(.bool(true)) == true)
        #expect(JSONReader.boolean(.string("true")) == true)
        #expect(JSONReader.boolean(.string("FALSE")) == false)
        #expect(JSONReader.boolean(.string("1")) == true)
        #expect(JSONReader.boolean(.string("0")) == false)
        #expect(JSONReader.boolean(.number(1)) == true)
        #expect(JSONReader.boolean(.number(0)) == false)
        #expect(JSONReader.boolean(.number(2)) == nil)
        #expect(JSONReader.boolean(.string("maybe")) == nil)
        #expect(
            JSONReader.boolean(.string("maybe"), fallback: false) == false
        )
        #expect(JSONReader.boolean(nil, fallback: true) == true)
        #expect(JSONReader.boolean(.null, fallback: false) == false)
        #expect(JSONReader.boolean(.array([]), fallback: true) == true)

        let object: WiroJSON = ["on": "1"]
        #expect(JSONReader.boolean(object, "on") == true)
        #expect(JSONReader.boolean(object, "missing", fallback: false) == false)
    }

    @Test("string coerces numbers and bools")
    func stringLeniency() {
        #expect(JSONReader.string(.string("hi")) == "hi")
        #expect(JSONReader.string(.number(42)) == "42")
        #expect(JSONReader.string(.number(3.5)) == "3.5")
        #expect(JSONReader.string(.bool(true)) == "true")
        #expect(JSONReader.string(.bool(false)) == "false")
        #expect(JSONReader.string(.array([])) == nil)
        #expect(JSONReader.string(.null) == nil)
        #expect(JSONReader.string(nil) == nil)
    }

    @Test("list and map extract collections")
    func collections() {
        let list: WiroJSONValue = [1, "a"]
        #expect(JSONReader.list(list)?.count == 2)

        let object: WiroJSON = [
            "inner": ["k": "v"],
            "items": [1, 2],
            "label": "hi",
            "flag": "true",
            "ratio": "2.5",
            "link": "https://wiro.ai/a",
            "ts": 1_700_000_000,
        ]
        #expect(JSONReader.map(object, "inner")?["k"]?.stringValue == "v")
        #expect(JSONReader.map(object, "missing") == nil)
        #expect(JSONReader.list(object, "items")?.count == 2)
        #expect(JSONReader.string(object, "label") == "hi")
        #expect(JSONReader.double(object, "ratio") == 2.5)
        #expect(JSONReader.boolean(object, "flag") == true)
        #expect(
            JSONReader.url(object, "link")?.absoluteString
                == "https://wiro.ai/a"
        )
        #expect(
            JSONReader.date(object, "ts")?.timeIntervalSince1970
                == 1_700_000_000
        )
    }

    @Test("map returns nil for non-object, non-string values")
    func mapRejectsWrongTypes() {
        #expect(JSONReader.map(.bool(true)) == nil)
        #expect(JSONReader.map(.number(1)) == nil)
        #expect(JSONReader.map(.array([])) == nil)
        #expect(JSONReader.map(.null) == nil)
    }

    @Test("map decodes nested JSON object strings")
    func nestedJSONObjectString() {
        let value: WiroJSONValue = .string(#"{"a":1,"b":"x"}"#)
        let mapped = JSONReader.map(value)
        #expect(mapped?["a"]?.intValue == 1)
        #expect(mapped?["b"]?.stringValue == "x")
    }

    @Test("empty nested JSON string reports malformed")
    func emptyNestedJSONString() {
        nonisolated(unsafe) var reported: String?
        let result = JSONReader.map(
            .string("   "),
            onMalformedJSON: { reported = $0 }
        )
        #expect(result == [:])
        #expect(reported == "   ")
    }

    @Test("malformed nested JSON yields empty object and invokes handler")
    func malformedNestedJSON() {
        nonisolated(unsafe) var reported: String?
        let handler: JSONReader.MalformedJSONHandler = { raw in
            reported = raw
        }

        let malformed: WiroJSONValue = .string("{not-json")
        let result = JSONReader.map(
            malformed,
            onMalformedJSON: handler
        )

        #expect(result == [:])
        #expect(reported == "{not-json")
    }

    @Test("nested JSON that is not an object reports malformed")
    func nestedJSONNonObject() {
        nonisolated(unsafe) var reported = false
        let result = JSONReader.map(
            .string("[1,2,3]"),
            onMalformedJSON: { _ in reported = true }
        )
        #expect(result == [:])
        #expect(reported)
    }

    @Test("url extracts absolute URL strings")
    func urlExtraction() {
        let url = JSONReader.url(.string("https://wiro.ai/file.png"))
        #expect(url?.absoluteString == "https://wiro.ai/file.png")
        #expect(JSONReader.url(.string("")) == nil)
        #expect(JSONReader.url(.string("   ")) == nil)
        #expect(JSONReader.url(.number(1)) == nil)
        #expect(JSONReader.url(.bool(true)) == nil)
    }

    @Test("date parses second and millisecond timestamps")
    func dateExtraction() {
        let seconds = JSONReader.date(.number(1_700_000_000))
        #expect(seconds?.timeIntervalSince1970 == 1_700_000_000)

        let millis = JSONReader.date(.string("1700000000000"))
        #expect(millis?.timeIntervalSince1970 == 1_700_000_000)

        #expect(JSONReader.date(.string("not-a-date")) == nil)
        #expect(JSONReader.date(.bool(true)) == nil)
        #expect(JSONReader.date(.number(.infinity)) == nil)
        #expect(JSONReader.date(.number(.nan)) == nil)
    }
}

@Suite("Identifiers")
struct IdentifierTests {
    @Test("WiroModelID accepts valid owner and project")
    func modelIDSuccess() throws {
        let id = try WiroModelID(
            owner: "openai",
            project: "gpt-image-2"
        )
        #expect(id.owner == "openai")
        #expect(id.project == "gpt-image-2")
        #expect(id.slug == "openai/gpt-image-2")
        #expect(id.description == "openai/gpt-image-2")
    }

    @Test("WiroModelID parsing succeeds for owner/project")
    func modelIDParsingSuccess() {
        let id = WiroModelID(parsing: "openai/gpt-image-2")
        #expect(id?.slug == "openai/gpt-image-2")

        let dotted = WiroModelID(parsing: "black-forest-labs/flux-2-pro")
        #expect(dotted?.owner == "black-forest-labs")
        #expect(dotted?.project == "flux-2-pro")
    }

    @Test("WiroModelID throws on invalid segments")
    func modelIDThrowsOnInvalid() {
        #expect(throws: WiroError.self) {
            try WiroModelID(owner: "a b", project: "x")
        }
        #expect(throws: WiroError.self) {
            try WiroModelID(owner: "", project: "x")
        }
        #expect(throws: WiroError.self) {
            try WiroModelID(owner: "-bad", project: "x")
        }
        #expect(throws: WiroError.self) {
            try WiroModelID(owner: "ok", project: "bad/slash")
        }
    }

    @Test("WiroModelID parsing fails for malformed strings")
    func modelIDParsingFailure() {
        #expect(WiroModelID(parsing: "") == nil)
        #expect(WiroModelID(parsing: "onlyowner") == nil)
        #expect(WiroModelID(parsing: "a/b/c") == nil)
        #expect(WiroModelID(parsing: "a b/x") == nil)
        #expect(WiroModelID(parsing: "/project") == nil)
        #expect(WiroModelID(parsing: "owner/") == nil)
    }

    @Test("WiroModelID Codable round-trip")
    func modelIDCodable() throws {
        let id = try WiroModelID(owner: "openai", project: "gpt-image-2")
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(WiroModelID.self, from: data)
        #expect(decoded == id)
    }

    @Test("WiroModelID decode fails for invalid slug")
    func modelIDDecodeFailure() {
        let data = Data(#""not-a-slug""#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WiroModelID.self, from: data)
        }
    }

    @Test("WiroTaskToken rejects empty values")
    func taskTokenValidation() {
        let token = WiroTaskToken(rawValue: "abc123")
        #expect(token?.rawValue == "abc123")
        #expect(token?.description == "abc123")
        #expect(WiroTaskToken(rawValue: "  token  ")?.rawValue == "token")
        #expect(WiroTaskToken(rawValue: "") == nil)
        #expect(WiroTaskToken(rawValue: "   ") == nil)
    }

    @Test("WiroTaskID rejects empty values")
    func taskIDValidation() {
        let id = WiroTaskID(rawValue: "42")
        #expect(id?.rawValue == "42")
        #expect(id?.description == "42")
        #expect(WiroTaskID(rawValue: "") == nil)
        #expect(WiroTaskID(rawValue: " \n ") == nil)
    }

    @Test("token and id Codable round-trip")
    func tokenAndIDCodable() throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let id = try #require(WiroTaskID(rawValue: "99"))

        let tokenData = try JSONEncoder().encode(token)
        let idData = try JSONEncoder().encode(id)

        let decodedToken = try JSONDecoder()
            .decode(WiroTaskToken.self, from: tokenData)
        let decodedID = try JSONDecoder()
            .decode(WiroTaskID.self, from: idData)

        #expect(decodedToken == token)
        #expect(decodedID == id)
    }

    @Test("token and id decode fail for empty strings")
    func tokenAndIDDecodeFailure() {
        let empty = Data(#""""#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WiroTaskToken.self, from: empty)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WiroTaskID.self, from: empty)
        }
    }
}

@Suite("WiroError")
struct WiroErrorTests {
    @Test("errorDescription returns the human-readable message")
    func descriptions() {
        #expect(
            WiroError.apiResult(
                message: "failed",
                code: "E1",
                statusCode: 200,
                responseBody: #"{"secret":"nope"}"#
            ).errorDescription == "failed"
        )
        #expect(
            WiroError.authentication(
                message: "auth",
                statusCode: 401,
                responseBody: nil
            ).errorDescription == "auth"
        )
        #expect(
            WiroError.validation(
                message: "bad input",
                statusCode: 400,
                responseBody: nil
            ).errorDescription == "bad input"
        )
        #expect(
            WiroError.rateLimited(
                message: "slow down",
                statusCode: 429,
                retryAfter: 2,
                responseBody: nil
            ).errorDescription == "slow down"
        )
        #expect(
            WiroError.unknownAPI(
                message: "boom",
                statusCode: 500,
                responseBody: nil
            ).errorDescription == "boom"
        )
        #expect(
            WiroError.schemaValidation(messages: ["a", "b"])
                .errorDescription == "a; b"
        )
        #expect(
            WiroError.schemaValidation(messages: [])
                .errorDescription == "Schema validation failed."
        )
        #expect(
            WiroError.network(message: "offline", underlying: "ECONN")
                .errorDescription == "offline"
        )
        #expect(
            WiroError.webSocket(message: "closed", underlying: nil)
                .errorDescription == "closed"
        )
        #expect(
            WiroError.timedOut(
                message: "deadline",
                timeout: .seconds(10)
            ).errorDescription == "deadline"
        )
        #expect(
            WiroError.cancelled.errorDescription
                == "The operation was cancelled."
        )
    }

    @Test("descriptions never surface response bodies")
    func descriptionsOmitBodies() {
        let error = WiroError.apiResult(
            message: "Application failed.",
            code: "X",
            statusCode: 200,
            responseBody: #"{"apiKey":"sk-secret","body":true}"#
        )
        let description = error.errorDescription ?? ""
        #expect(!description.contains("sk-secret"))
        #expect(!description.contains("apiKey"))
        #expect(description == "Application failed.")
    }
}
