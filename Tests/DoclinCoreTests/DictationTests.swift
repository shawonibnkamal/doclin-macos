import Foundation
import DoclinCore

extension CoreTests {
    func testLocalVoiceSettingsMigrateAutomaticAndPreserveExplicitChoice() throws {
        var p = Preferences(); p.systemVoice = ""; try p.save()
        XCTAssertEqual(Preferences.load().systemVoice, "kokoro:2")
        p.systemVoice = "kokoro:3"; try p.save()
        XCTAssertEqual(Preferences.load().systemVoice, "kokoro:3")
        p.systemVoice = "explicit-mac-voice"; try p.save()
        XCTAssertEqual(Preferences.load().systemVoice, "explicit-mac-voice")
        XCTAssertEqual(LocalVoiceChoice.speaker(for: "kokoro:16"), 16)
        XCTAssertNil(LocalVoiceChoice.speaker(for: "kokoro:99"))
        XCTAssertEqual(LocalVoiceChoice.spoken("Changes are ready"), "Changes are ready.")
        XCTAssertEqual(LocalVoiceChoice.spoken("Do not deploy!"), "Do not deploy!")
    }

    func testTimedTranscriptKeepsFinalRangesAndRevisesOnlyActiveWords() {
        var b = TimedTranscript()
        XCTAssertEqual(b.update("Please review.", start: 0, end: 2, final: true), "Please review.")
        XCTAssertEqual(b.update(" Fifteen", start: 3, end: 4, final: false), "Please review. Fifteen")
        XCTAssertEqual(b.update(" Fifty records.", start: 3, end: 5, final: true), "Please review. Fifty records.")
        XCTAssertEqual(b.update(" Fifteen", start: 3, end: 4, final: false), "Please review. Fifty records.")
        XCTAssertEqual(b.update(" Thank you.", start: 7, end: 9, final: true), "Please review. Fifty records. Thank you.")
        XCTAssertEqual(b.update(" Thank you.", start: 7, end: 9, final: true), "Please review. Fifty records. Thank you.")
        XCTAssertEqual(b.update(" Thank you.", start: 10, end: 12, final: true), "Please review. Fifty records. Thank you. Thank you.")
        XCTAssertEqual(b.update("Invalid", start: .nan, end: 15, final: true), "Please review. Fifty records. Thank you. Thank you.")
    }
    func testTranscriptKeepsPhrasesAcrossPauses() {
        var b = TranscriptBuffer()
        XCTAssertEqual(b.update("Please review the whole proposal.", completedUtterance: true, start: 0), "Please review the whole proposal.")
        XCTAssertEqual(b.update("before", completedUtterance: false, start: nil), "Please review the whole proposal. before")
        XCTAssertEqual(b.update("before Friday.", completedUtterance: true, start: 4), "Please review the whole proposal. before Friday.")
        XCTAssertEqual(b.update("Thank you", completedUtterance: true, start: 8), "Please review the whole proposal. before Friday. Thank you")
        XCTAssertEqual(b.update("Thank you", completedUtterance: true, start: 8), "Please review the whole proposal. before Friday. Thank you")
    }
    func testTranscriptRepetitionDoesNotEraseEarlierPhrases() {
        var b = TranscriptBuffer()
        _ = b.update("Thank you.", completedUtterance: true, start: 0)
        _ = b.update("See you.", completedUtterance: false, start: nil)
        _ = b.update("See you.", completedUtterance: true, start: 2)
        XCTAssertEqual(b.update("Thank you.", completedUtterance: false, start: nil), "Thank you. See you. Thank you.")
        XCTAssertEqual(b.update("Thank you.", completedUtterance: true, start: 4), "Thank you. See you. Thank you.")
    }
    func testTranscriptDuplicateCallbacksAndCumulativeFinal() {
        var b = TranscriptBuffer()
        _ = b.update("Hello.", completedUtterance: true, start: 0)
        XCTAssertEqual(b.update("Hello.", completedUtterance: false, start: nil), "Hello.")
        XCTAssertEqual(b.update("Hello", completedUtterance: false, start: nil), "Hello.")
        _ = b.update("Second", completedUtterance: false, start: nil)
        XCTAssertEqual(b.update("Hello. Second.", completedUtterance: true, start: 0), "Hello. Second.")
        var c = TranscriptBuffer()
        _ = c.update("First.", completedUtterance: true, start: 0)
        _ = c.update("Second.", completedUtterance: true, start: 3)
        XCTAssertEqual(c.update("First. Second.", completedUtterance: true, start: 0), "First. Second.")
    }
    func testTranscriptRevisesWithoutDuplicating() {
        var b = TranscriptBuffer()
        _ = b.update("Pay fifteen", completedUtterance: false, start: nil)
        XCTAssertEqual(b.update("Pay fifty dollars.", completedUtterance: true, start: 0), "Pay fifty dollars.")
        XCTAssertEqual(b.update("Pay fifty dollars. Tomorrow.", completedUtterance: false, start: nil), "Pay fifty dollars. Tomorrow.")
        XCTAssertEqual(b.update("", completedUtterance: true, start: 0), "Pay fifty dollars. Tomorrow.")
        var repeated = TranscriptBuffer()
        _ = repeated.update("No.", completedUtterance: true, start: 0)
        XCTAssertEqual(repeated.update("No.", completedUtterance: false, start: nil), "No.")
        XCTAssertEqual(repeated.update("No.", completedUtterance: true, start: 3), "No. No.")
    }

    func testRightCommandHoldAvoidsChordsAndQuickTaps() {
        var hold = ModifierHold()
        XCTAssertEqual(hold.update(down: true, chord: false), .arm)
        XCTAssertEqual(hold.update(down: false, chord: false), .none)
        XCTAssertFalse(hold.activate())
        XCTAssertEqual(hold.update(down: true, chord: false), .arm)
        _ = hold.update(down: true, chord: true)
        XCTAssertFalse(hold.activate())
        XCTAssertEqual(hold.update(down: true, chord: false), .none)
        _ = hold.update(down: false, chord: false)
        _ = hold.update(down: true, chord: false)
        XCTAssertTrue(hold.activate())
        XCTAssertEqual(hold.update(down: true, chord: true), .cancel)
        XCTAssertEqual(hold.update(down: false, chord: false), .none)
        _ = hold.update(down: true, chord: false)
        XCTAssertTrue(hold.activate())
        XCTAssertEqual(hold.update(down: false, chord: false), .release)
    }

    func testDictationCannotOverlapAndCompletesOnce() throws {
        var state = DictationLifecycle()
        let id = try XCTUnwrap(state.begin())
        XCTAssertNil(state.begin()); XCTAssertTrue(state.finishRecording()); XCTAssertFalse(state.finishRecording())
        XCTAssertTrue(state.complete(id)); XCTAssertFalse(state.complete(id)); XCTAssertEqual(state.phase, .idle)
    }
    func testCancelRejectsLateTranscriptAndOldSession() throws {
        var state = DictationLifecycle(); let old = try XCTUnwrap(state.begin()); state.cancel()
        let current = try XCTUnwrap(state.begin())
        XCTAssertFalse(state.accepts(old)); XCTAssertFalse(state.complete(old)); XCTAssertTrue(state.accepts(current))
    }
    func testDictationPreservesLongTextCodeAndURLs() {
        let text = "Please use `buyer_id`, not `seller_id`.\n\nOpen https://example.com and check all 42 records. " + String(repeating: "Keep my words. ", count: 30)
        XCTAssertEqual(DictationText.normalized("  " + text + "  "), text.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertTrue(DictationText.normalized(text).count > 350)
    }
    func testCleanupRejectsLostNumbersAndSevereOmissions() {
        XCTAssertFalse(DictationText.usableCleanup("Pay 15 dollars.", original: "Pay 50 dollars."))
        XCTAssertFalse(DictationText.usableCleanup("Hello.", original: String(repeating: "The release was not approved. ", count: 15)))
        XCTAssertTrue(DictationText.usableCleanup("Please check all 42 records.", original: "um please check all 42 records"))
    }
    func testTranscriptionMultipartPreservesBinaryAndUsesChosenModel() {
        let bytes = Data([0, 255, 10, 13, 77])
        let data = CloudService.transcriptionBody(audio: bytes, boundary: "test-boundary", language: "en", terms: ["Doclin", "Codex"])
        XCTAssertTrue(data.range(of: bytes) != nil)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("gpt-4o-mini-transcribe")); XCTAssertTrue(text.contains("name=\"file\"; filename=\"dictation.m4a\""))
        XCTAssertTrue(text.hasSuffix("--test-boundary--\r\n")); XCTAssertTrue(text.contains("Doclin, Codex"))
    }
    func testDictationSettingsAreSeparateAndOfflineByDefault() throws {
        let defaults = DictationPreferences()
        XCTAssertFalse(defaults.enabled); XCTAssertFalse(defaults.cleanup); XCTAssertEqual(defaults.provider, "local")
        var p = Preferences(); p.muted = true; try p.save()
        var d = DictationPreferences(); d.enabled = true; d.vocabulary = " one, two , "
        try d.save(); XCTAssertEqual(DictationPreferences.load().terms, ["one", "two"])
        XCTAssertTrue(Preferences.load().muted)
    }
}

func runDictationCloudChecks() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
    let cloud = CloudService(session: session)
    MockURLProtocol.status = 200; MockURLProtocol.responseBody = Data(#"{"text":"Do not deploy the 42 changes.\nReview them first."}"#.utf8)
    let transcript = try await cloud.transcribe(audio: Data([0, 1, 2]), key: "test-placeholder", locale: "en-CA", terms: ["Doclin"])
    XCTAssertEqual(transcript, "Do not deploy the 42 changes.\nReview them first.")
    XCTAssertEqual(MockURLProtocol.requests.last?.url?.path, "/v1/audio/transcriptions")
    XCTAssertTrue(MockURLProtocol.requests.last?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=Doclin-") == true)
    MockURLProtocol.status = 401
    do { _ = try await cloud.transcribe(audio: Data([1]), key: "test-placeholder", locale: "en", terms: []); check(false, "Bad key must fail") } catch {}
    MockURLProtocol.status = 200
    MockURLProtocol.responseBody = Data(#"{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Check all 42 records."}]}]}"#.utf8)
    XCTAssertEqual(try await cloud.cleanDictation("um check all 42 records", key: "test-placeholder"), "Check all 42 records.")
    MockURLProtocol.responseBody = Data(#"{"status":"incomplete","output":[]}"#.utf8)
    do { _ = try await cloud.cleanDictation("Please preserve my whole message.", key: "test-placeholder"); check(false, "Partial cleanup must not replace transcript") } catch {}
    print("PASS dictation transcription and cleanup mock transport checks")
}
