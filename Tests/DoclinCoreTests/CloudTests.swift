import Foundation
import DoclinCore

final class MockURLProtocol: URLProtocol {
    static var responseBody = Data()
    static var status = 200
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

func runCloudChecks() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let cloud = CloudService(session: session)
    MockURLProtocol.status = 200
    MockURLProtocol.responseBody = Data(#"{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Checkout: the tests failed; deployment is blocked."}]}]}"#.utf8)
    let result = try await cloud.summarize(AgentEvent(source: "Claude", session: "a", text: "Tests failed; not deployed.", project: "Checkout"), key: "test-placeholder", words: 20)
    XCTAssertTrue(result.contains("failed"))
    let request = try XCTUnwrap(MockURLProtocol.requests.last)
    XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-placeholder")
    var body = request.httpBody ?? Data()
    if body.isEmpty, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 8192)
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(buffer, count: n) }
    }
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(json["store"] as? Bool, false)
    XCTAssertEqual(json["model"] as? String, "gpt-4o-mini")
    XCTAssertEqual(json["max_output_tokens"] as? Int, 100)
    MockURLProtocol.status = 401
    do { _ = try await cloud.summarize(AgentEvent(source: "Claude", session: "a"), key: "test-placeholder", words: 20); check(false, "401 must fail") }
    catch { XCTAssertTrue(error.localizedDescription.contains("key was rejected")) }
    MockURLProtocol.status = 200; MockURLProtocol.responseBody = Data([1, 2, 3])
    let audio = try await cloud.speech("A response is ready.", key: "test-placeholder", voice: "coral", rate: 1)
    XCTAssertEqual(audio.count, 3)
    XCTAssertEqual(MockURLProtocol.requests.last?.url?.path, "/v1/audio/speech")
    print("PASS cloud request serialization, retention flag, error handling, TTS endpoint (mock transport)")
}
