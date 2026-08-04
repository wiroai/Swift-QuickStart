import Foundation
import Testing
@testable import WiroKit

@Suite("Discovery models")
struct DiscoveryModelTests {
    @Test("parses a model list item with stringified numbers")
    func parseModel() throws {
        let json: WiroJSON = try decodeObject(
            #"""
            {
              "id": "42",
              "title": "Flux 2 Pro",
              "cleanslugowner": "black-forest-labs",
              "cleanslugproject": "flux-2-pro",
              "description": "Image model",
              "seodescription": "SEO",
              "image": "https://cdn.wiro.ai/flux.png",
              "categories": ["image"],
              "tags": ["flux", "pro"],
              "samples": ["https://cdn.wiro.ai/s1.png"],
              "computingtime": "8s",
              "approximatelycost": "0.04",
              "dynamicprice": "tier-a",
              "cps": "0.01",
              "taskstat": {
                "runcount": "100",
                "successcount": 90,
                "errorcount": "10",
                "lastruntime": 1700000000
              }
            }
            """#
        )

        let model = WiroModel.parse(json)
        #expect(model.id == "42")
        #expect(model.owner == "black-forest-labs")
        #expect(model.slug == "flux-2-pro")
        #expect(model.title == "Flux 2 Pro")
        #expect(model.description == "Image model")
        #expect(model.seoDescription == "SEO")
        #expect(model.imageURL?.absoluteString == "https://cdn.wiro.ai/flux.png")
        #expect(model.categories == ["image"])
        #expect(model.tags == ["flux", "pro"])
        #expect(model.samples == ["https://cdn.wiro.ai/s1.png"])
        #expect(model.computingTime == "8s")
        #expect(model.approximateCost == "0.04")
        #expect(model.dynamicPrice == "tier-a")
        #expect(model.cps == "0.01")
        #expect(model.taskStats?.runCount == 100)
        #expect(model.taskStats?.successCount == 90)
        #expect(model.taskStats?.errorCount == 10)
        #expect(model.taskStats?.lastRunTime?.timeIntervalSince1970 == 1_700_000_000)
        #expect(model.modelID?.slug == "black-forest-labs/flux-2-pro")
        #expect(model.raw["id"]?.stringValue == "42")
    }

    @Test("sort and order api values match the wire protocol")
    func sortWireValues() {
        #expect(WiroModelSort.relevance.apiValue == "relevance")
        #expect(WiroModelSort.time.apiValue == "time")
        #expect(WiroModelSort.ratedUserCount.apiValue == "ratedusercount")
        #expect(WiroModelSort.commentCount.apiValue == "commentcount")
        #expect(WiroModelSort.averagePoint.apiValue == "averagepoint")
        #expect(WiroSortOrder.ascending.apiValue == "ASC")
        #expect(WiroSortOrder.descending.apiValue == "DESC")
    }

    @Test("schema parses every parameter kind including unknown")
    func parseSchemaKinds() throws {
        let json: WiroJSON = try decodeObject(schemaFixtureJSON)
        let schema = WiroModelSchema.parse(json)

        #expect(schema.model.slug == "demo-model")
        #expect(schema.readme == "# Demo")
        #expect(schema.parameterGroups.count == 1)
        #expect(schema.parameters.count == 5)

        guard case .text(let textInfo, let textDefault) = schema.parameters[0]
        else {
            Issue.record("Expected text parameter")
            return
        }
        #expect(textInfo.name == "prompt")
        #expect(textInfo.isRequired)
        #expect(textDefault == "hello")

        guard case .select(_, let options, let selectDefault) =
            schema.parameters[1]
        else {
            Issue.record("Expected select parameter")
            return
        }
        #expect(options.map(\.value) == ["jpeg", "png"])
        #expect(selectDefault == "png")

        guard case .number(_, let numberDefault, let min, let max, let step) =
            schema.parameters[2]
        else {
            Issue.record("Expected number parameter")
            return
        }
        #expect(numberDefault == 1024)
        #expect(min == 64)
        #expect(max == 2048)
        #expect(step == 16)

        guard case .file(let fileInfo) = schema.parameters[3] else {
            Issue.record("Expected file parameter")
            return
        }
        #expect(fileInfo.name == "inputImage")
        #expect(!fileInfo.isRequired)

        guard case .unknown(_, let type, _) = schema.parameters[4] else {
            Issue.record("Expected unknown parameter")
            return
        }
        #expect(type == "futureType")
    }

    @Test("schema.validate happy path and each violation kind")
    func schemaValidate() throws {
        let schema = WiroModelSchema.parse(try decodeObject(schemaFixtureJSON))

        #expect(
            schema.validate([
                "prompt": "a cat",
                "outputFormat": "png",
                "width": 1024,
            ]).isEmpty
        )

        let missing = schema.validate([:])
        #expect(missing.contains("prompt is required"))

        let badSelect = schema.validate([
            "prompt": "x",
            "outputFormat": "gif",
        ])
        #expect(
            badSelect.contains {
                $0.contains("outputFormat must be one of")
            }
        )

        let nonNumeric = schema.validate([
            "prompt": "x",
            "width": "wide",
        ])
        #expect(nonNumeric.contains("width must be numeric"))

        let tooSmall = schema.validate([
            "prompt": "x",
            "width": 32,
        ])
        #expect(tooSmall.contains("width must be at least 64"))

        let tooLarge = schema.validate([
            "prompt": "x",
            "width": 4096,
        ])
        #expect(tooLarge.contains("width must be at most 2048"))

        // Unknown keys are allowed.
        #expect(
            schema.validate([
                "prompt": "ok",
                "extra": "ignored",
            ]).isEmpty
        )
    }

    @Test("explore category parses nested models")
    func parseExplore() throws {
        let json: WiroJSON = try decodeObject(
            #"""
            {
              "id": "featured",
              "title": "Featured",
              "total": "2",
              "url": "https://wiro.ai/explore/featured",
              "tools": [
                {
                  "id": "1",
                  "slugowner": "openai",
                  "slugproject": "gpt-image-2",
                  "title": "GPT Image 2"
                }
              ]
            }
            """#
        )
        let category = WiroExploreCategory.parse(json)
        #expect(category.id == "featured")
        #expect(category.title == "Featured")
        #expect(category.total == 2)
        #expect(category.models.count == 1)
        #expect(category.models[0].owner == "openai")
        #expect(category.models[0].slug == "gpt-image-2")
    }
}

@Suite("Discovery client")
struct DiscoveryClientTests {
    @Test("searchModels sends exact /Tool/List body semantics")
    func searchModelsRequestBody() async throws {
        let transport = MockHTTPTransport { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Tool/List"
            )
            let body = try decodeRequestBody(request)
            #expect(body["start"] == .string("0"))
            #expect(body["limit"] == .string("20"))
            #expect(body["search"] == .string("flux"))
            #expect(body["categories"] == .array([.string("image")]))
            #expect(body["sort"] == .string("relevance"))
            #expect(body["hideworkflows"] == .bool(true))
            #expect(body["summary"] == .bool(true))
            #expect(body["slugowner"] == .string("openai"))
            #expect(body["order"] == .string("DESC"))
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "result": true,
                  "total": "1",
                  "tool": [
                    {
                      "id": "1",
                      "cleanslugowner": "openai",
                      "cleanslugproject": "gpt-image-2",
                      "title": "GPT Image 2"
                    }
                  ]
                }
                """#
            )
        }

        let client = try await ClientFixtures.makeClient(transport: transport)
        let page = try await client.searchModels(
            search: "flux",
            categories: ["image"],
            start: 0,
            limit: 20,
            sort: .relevance,
            owner: "openai",
            order: .descending
        )

        #expect(page.isSuccess)
        #expect(page.total == 1)
        #expect(page.items.count == 1)
        #expect(page.items[0].slug == "gpt-image-2")
        #expect(await transport.requestCount == 1)
    }

    @Test("searchModels omits optional owner and order when nil")
    func searchModelsOmitsOptionals() async throws {
        let transport = MockHTTPTransport { request in
            let body = try decodeRequestBody(request)
            #expect(body["slugowner"] == nil)
            #expect(body["order"] == nil)
            #expect(body["hideworkflows"] == .bool(true))
            #expect(body["summary"] == .bool(true))
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true,"total":0,"tool":[]}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let page = try await client.searchModels()
        #expect(page.items.isEmpty)
        #expect(page.total == 0)
    }

    @Test("searchModels validates start and limit")
    func searchModelsValidation() async throws {
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport()
        )
        do {
            _ = try await client.searchModels(start: -1)
            Issue.record("Expected validation for start")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }

        do {
            _ = try await client.searchModels(limit: 0)
            Issue.record("Expected validation for limit")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }

        do {
            _ = try await client.searchModels(limit: 101)
            Issue.record("Expected validation for limit 101")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("searchModels empty results and result:false errors")
    func searchModelsEmptyAndErrors() async throws {
        let emptyTransport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"{"result":true,"total":0,"tool":[]}"#
            )
        }
        let emptyClient = try await ClientFixtures.makeClient(
            transport: emptyTransport
        )
        let empty = try await emptyClient.searchModels()
        #expect(empty.items.isEmpty)
        #expect(empty.total == 0)

        let errorTransport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "result": false,
                  "errors": [{"code":"E1","message":"nope"}],
                  "tool": []
                }
                """#
            )
        }
        let errorClient = try await ClientFixtures.makeClient(
            transport: errorTransport,
            retryPolicy: .none
        )
        do {
            _ = try await errorClient.searchModels()
            Issue.record("Expected apiResult")
        } catch let error as WiroError {
            guard case .apiResult(let message, let code, _, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message == "nope")
            #expect(code == "E1")
        }
    }

    @Test("explore parses categories from /Tool/Explore")
    func exploreRequest() async throws {
        let transport = MockHTTPTransport { request in
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Tool/Explore"
            )
            let body = try decodeRequestBody(request)
            #expect(body.isEmpty)
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "explore": [
                    {
                      "id": "hot",
                      "title": "Hot",
                      "tools": [
                        {
                          "id": "1",
                          "slugowner": "xai",
                          "slugproject": "grok-imagine-image"
                        }
                      ]
                    }
                  ]
                }
                """#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let categories = try await client.explore()
        #expect(categories.count == 1)
        #expect(categories[0].title == "Hot")
        #expect(categories[0].models[0].owner == "xai")
    }

    @Test("getModelSchema posts owner/project and parses schema")
    func getModelSchema() async throws {
        let model = try WiroModelID(
            owner: "black-forest-labs",
            project: "flux-2-pro"
        )
        let transport = MockHTTPTransport { request in
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Tool/Detail"
            )
            let body = try decodeRequestBody(request)
            #expect(body["slugowner"] == .string("black-forest-labs"))
            #expect(body["slugproject"] == .string("flux-2-pro"))
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "tool": [
                \#(schemaFixtureObjectLiteral)
                  ]
                }
                """#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let schema = try await client.getModelSchema(model)
        #expect(schema.model.slug == "demo-model")
        #expect(schema.parameters.count == 5)
    }

    @Test("getModelSchema throws when tool array is empty")
    func getModelSchemaEmpty() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, json: #"{"tool":[]}"#)
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let model = try WiroModelID(owner: "a", project: "b")
        do {
            _ = try await client.getModelSchema(model)
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }
}

// MARK: - Fixtures

private let schemaFixtureObjectLiteral = #"""
{
  "id": "9",
  "cleanslugowner": "demo",
  "cleanslugproject": "demo-model",
  "readme": "# Demo",
  "parameters": [
    {
      "title": "Inputs",
      "items": [
        {
          "id": "prompt",
          "type": "textarea",
          "label": "Prompt",
          "required": true,
          "default": "hello"
        },
        {
          "id": "outputFormat",
          "type": "select",
          "label": "Format",
          "required": false,
          "default": "png",
          "options": [
            {"label": "JPEG", "value": "jpeg"},
            {"label": "PNG", "value": "png"}
          ]
        },
        {
          "id": "width",
          "type": "number",
          "label": "Width",
          "required": false,
          "default": 1024,
          "min": 64,
          "max": 2048,
          "step": 16
        },
        {
          "id": "inputImage",
          "type": "fileinput",
          "label": "Image",
          "required": false
        },
        {
          "id": "magic",
          "type": "futureType",
          "label": "Magic",
          "required": false,
          "default": {"x": 1}
        }
      ]
    }
  ]
}
"""#

private let schemaFixtureJSON = schemaFixtureObjectLiteral

private func decodeObject(_ json: String) throws -> WiroJSON {
    let data = Data(json.utf8)
    let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
    guard case .object(let object) = value else {
        throw WiroError.unknownAPI(
            message: "Expected object fixture",
            statusCode: 0,
            responseBody: nil
        )
    }
    return object
}

private func decodeRequestBody(_ request: URLRequest) throws -> WiroJSON {
    guard let data = request.httpBody else { return [:] }
    let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
    guard case .object(let object) = value else { return [:] }
    return object
}
