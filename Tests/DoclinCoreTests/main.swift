import Foundation
var failures = 0
func check(_ valid: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) { if !valid { failures += 1; print("FAIL \(file):\(line): \(message)") } }
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { check(value, "Expected true", file: file, line: line) }
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { check(!value, "Expected false", file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { check(a == b, "Expected \(a) == \(b)", file: file, line: line) }
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { check(value == nil, "Expected nil", file: file, line: line) }
func XCTAssertLessThanOrEqual<T: Comparable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { check(a <= b, "Expected <=", file: file, line: line) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { _ = try expression(); check(false, "Expected error", file: file, line: line) } catch {} }
func XCTUnwrap<T>(_ value: T?) throws -> T { guard let value else { throw NSError(domain: "Test", code: 1) }; return value }
let support = FileManager.default.temporaryDirectory.appendingPathComponent("doclin-checks-" + UUID().uuidString)
setenv("DOCLIN_SUPPORT_DIR", support.path, 1)
let suite = CoreTests()
let checks: [(String, () throws -> Void)] = [
("testTranscriptRepetitionDoesNotEraseEarlierPhrases", suite.testTranscriptRepetitionDoesNotEraseEarlierPhrases),
("testTranscriptDuplicateCallbacksAndCumulativeFinal", suite.testTranscriptDuplicateCallbacksAndCumulativeFinal),
("testTranscriptKeepsPhrasesAcrossPauses", suite.testTranscriptKeepsPhrasesAcrossPauses),
("testTranscriptRevisesWithoutDuplicating", suite.testTranscriptRevisesWithoutDuplicating),
("testDuplicateCompletionOnlySpeaksOnce", suite.testDuplicateCompletionOnlySpeaksOnce),
("testNewCompletionReplacesSameTaskOnly", suite.testNewCompletionReplacesSameTaskOnly),
("testNewPromptCancelsPending", suite.testNewPromptCancelsPending),
("testDelayedOldCompletionCannotReappearAfterNewPrompt", suite.testDelayedOldCompletionCannotReappearAfterNewPrompt),
("testOldAnnouncementsExpireBeforeAdmissionAndPlayback", suite.testOldAnnouncementsExpireBeforeAdmissionAndPlayback),
("testQueueIsBounded", suite.testQueueIsBounded),
("testFormattingDoesNotReadCodeURLsOrMarkdown", suite.testFormattingDoesNotReadCodeURLsOrMarkdown),
("testExcerptPreservesNegativeOutcomeAndWordCap", suite.testExcerptPreservesNegativeOutcomeAndWordCap),
("testEmptyCompletionIsNotClaimedSuccess", suite.testEmptyCompletionIsNotClaimedSuccess),
("testCodexDesktopShapeAndSubagentExclusion", suite.testCodexDesktopShapeAndSubagentExclusion),
("testCodexUnknownTimestampAndToolOutputsAreIgnored", suite.testCodexUnknownTimestampAndToolOutputsAreIgnored),
("testClaudeHookNormalizesStopAndStartButNotSubagents", suite.testClaudeHookNormalizesStopAndStartButNotSubagents),
("testIntegrationPreservesOtherHooksAndIsIdempotent", suite.testIntegrationPreservesOtherHooksAndIsIdempotent),
("testInvalidSettingsFailWithoutOverwriting", suite.testInvalidSettingsFailWithoutOverwriting),
("testShellQuotingCannotExecutePathContent", suite.testShellQuotingCannotExecutePathContent),
("testTailBuffersPartialLinesAndDoesNotReplayBaseline", suite.testTailBuffersPartialLinesAndDoesNotReplayBaseline),
("testCloudResponseParsesMessagesAfterReasoningAndRejectsPartial", suite.testCloudResponseParsesMessagesAfterReasoningAndRejectsPartial),
("testProjectExclusionAndSourceToggles", suite.testProjectExclusionAndSourceToggles),
("testProducerDoesNotCollectWhenAppIsClosedOrMuted", suite.testProducerDoesNotCollectWhenAppIsClosedOrMuted),
("testWatcherDeliversFreshLifecycleEventsWithoutReplayingOldFiles", suite.testWatcherDeliversFreshLifecycleEventsWithoutReplayingOldFiles),
("testRightCommandHoldAvoidsChordsAndQuickTaps", suite.testRightCommandHoldAvoidsChordsAndQuickTaps),
("testDictationCannotOverlapAndCompletesOnce", suite.testDictationCannotOverlapAndCompletesOnce),
("testCancelRejectsLateTranscriptAndOldSession", suite.testCancelRejectsLateTranscriptAndOldSession),
("testDictationPreservesLongTextCodeAndURLs", suite.testDictationPreservesLongTextCodeAndURLs),
("testCleanupRejectsLostNumbersAndSevereOmissions", suite.testCleanupRejectsLostNumbersAndSevereOmissions),
("testTranscriptionMultipartPreservesBinaryAndUsesChosenModel", suite.testTranscriptionMultipartPreservesBinaryAndUsesChosenModel),
("testDictationSettingsAreSeparateAndOfflineByDefault", suite.testDictationSettingsAreSeparateAndOfflineByDefault)
]
for (name, run) in checks { let before = failures; do { try run() } catch { failures += 1; print("FAIL \(name): \(error)") }; if before == failures { print("PASS \(name)") } }
let signal = DispatchSemaphore(value: 0)
Task.detached {
    do { try await runCloudChecks(); try await runDictationCloudChecks() } catch { failures += 1; print("FAIL cloud checks: \(error)") }
    signal.signal()
}
if signal.wait(timeout: .now() + 15) == .timedOut { failures += 1; print("FAIL cloud checks timed out") }
print("\(checks.count) core checks plus cloud transport checks, \(failures) failures")
try? FileManager.default.removeItem(at: support)
exit(failures == 0 ? 0 : 1)
