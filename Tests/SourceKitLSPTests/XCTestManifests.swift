#if !canImport(ObjectiveC)
import XCTest

extension BuildSystemTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__BuildSystemTests = [
        ("testClangdDocumentFallbackWithholdsDiagnostics", testClangdDocumentFallbackWithholdsDiagnostics),
        ("testClangdDocumentUpdatedBuildSettings", testClangdDocumentUpdatedBuildSettings),
        ("testMainFilesChanged", testMainFilesChanged),
        ("testSwiftDocumentBuildSettingsChangedFalseAlarm", testSwiftDocumentBuildSettingsChangedFalseAlarm),
        ("testSwiftDocumentFallbackWithholdsSemanticDiagnostics", testSwiftDocumentFallbackWithholdsSemanticDiagnostics),
        ("testSwiftDocumentUpdatedBuildSettings", testSwiftDocumentUpdatedBuildSettings),
    ]
}

extension CodeActionTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__CodeActionTests = [
        ("testCodeActionResponseCommandMetadataInjection", testCodeActionResponseCommandMetadataInjection),
        ("testCodeActionResponseIgnoresSupportedKinds", testCodeActionResponseIgnoresSupportedKinds),
        ("testCodeActionResponseLegacySupport", testCodeActionResponseLegacySupport),
        ("testCommandEncoding", testCommandEncoding),
        ("testEmptyCodeActionResult", testEmptyCodeActionResult),
        ("testSemanticRefactorLocalRenameResult", testSemanticRefactorLocalRenameResult),
        ("testSemanticRefactorLocationCodeActionResult", testSemanticRefactorLocationCodeActionResult),
        ("testSemanticRefactorRangeCodeActionResult", testSemanticRefactorRangeCodeActionResult),
    ]
}

extension DocumentColorTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DocumentColorTests = [
        ("testEmptyText", testEmptyText),
        ("testPresentation", testPresentation),
        ("testSimple", testSimple),
        ("testWeirdWhitespace", testWeirdWhitespace),
    ]
}

extension DocumentSymbolTest {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__DocumentSymbolTest = [
        ("testAll", testAll),
        ("testEmpty", testEmpty),
        ("testEnum", testEnum),
        ("testStruct", testStruct),
        ("testUnicode", testUnicode),
    ]
}

extension ExecuteCommandTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ExecuteCommandTests = [
        ("testLocationSemanticRefactoring", testLocationSemanticRefactoring),
        ("testLSPCommandMetadataRemoval", testLSPCommandMetadataRemoval),
        ("testLSPCommandMetadataRetrieval", testLSPCommandMetadataRetrieval),
        ("testRangeSemanticRefactoring", testRangeSemanticRefactoring),
    ]
}

extension FoldingRangeTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__FoldingRangeTests = [
        ("testLineFoldingOnly", testLineFoldingOnly),
        ("testNoRanges", testNoRanges),
        ("testPartialLineFolding", testPartialLineFolding),
        ("testRangeLimit", testRangeLimit),
    ]
}

extension ImplementationTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__ImplementationTests = [
        ("testImplementation", testImplementation),
    ]
}

extension InlayHintsTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__InlayHintsTests = [
        ("testBindings", testBindings),
        ("testClosureParams", testClosureParams),
        ("testEmpty", testEmpty),
        ("testExplicitTypeAnnotation", testExplicitTypeAnnotation),
        ("testFields", testFields),
        ("testRanged", testRanged),
    ]
}

extension LocalClangTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__LocalClangTests = [
        ("testClangModules", testClangModules),
        ("testClangStdHeaderCanary", testClangStdHeaderCanary),
        ("testFoldingRange", testFoldingRange),
        ("testSemanticHighlighting", testSemanticHighlighting),
        ("testSymbolInfo", testSymbolInfo),
    ]
}

extension LocalSwiftTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__LocalSwiftTests = [
        ("testCrossFileDiagnostics", testCrossFileDiagnostics),
        ("testDiagnosticsReopen", testDiagnosticsReopen),
        ("testDocumentSymbolHighlight", testDocumentSymbolHighlight),
        ("testEditing", testEditing),
        ("testEditingNonURL", testEditingNonURL),
        ("testEditorPlaceholderParsing", testEditorPlaceholderParsing),
        ("testEducationalNotesAreUsedAsDiagnosticCodes", testEducationalNotesAreUsedAsDiagnosticCodes),
        ("testExcludedDocumentSchemeDiagnostics", testExcludedDocumentSchemeDiagnostics),
        ("testFixitInsert", testFixitInsert),
        ("testFixitsAreIncludedInPublishDiagnostics", testFixitsAreIncludedInPublishDiagnostics),
        ("testFixitsAreIncludedInPublishDiagnosticsNotes", testFixitsAreIncludedInPublishDiagnosticsNotes),
        ("testFixitsAreReturnedFromCodeActions", testFixitsAreReturnedFromCodeActions),
        ("testFixitsAreReturnedFromCodeActionsNotes", testFixitsAreReturnedFromCodeActionsNotes),
        ("testFixitTitle", testFixitTitle),
        ("testHover", testHover),
        ("testHoverNameEscaping", testHoverNameEscaping),
        ("testMuliEditFixitCodeActionNote", testMuliEditFixitCodeActionNote),
        ("testMuliEditFixitCodeActionPrimary", testMuliEditFixitCodeActionPrimary),
        ("testSymbolInfo", testSymbolInfo),
        ("testXMLToMarkdownComment", testXMLToMarkdownComment),
        ("testXMLToMarkdownDeclaration", testXMLToMarkdownDeclaration),
    ]
}

extension MainFilesProviderTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__MainFilesProviderTests = [
        ("testMainFilesChanged", testMainFilesChanged),
    ]
}

extension SKTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SKTests = [
        ("testClangdGoToDefinitionWithoutIndex", testClangdGoToDefinitionWithoutIndex),
        ("testClangdGoToInclude", testClangdGoToInclude),
        ("testCodeCompleteSwiftTibs", testCodeCompleteSwiftTibs),
        ("testDependenciesUpdatedCXXTibs", testDependenciesUpdatedCXXTibs),
        ("testDependenciesUpdatedSwiftTibs", testDependenciesUpdatedSwiftTibs),
        ("testIndexShutdown", testIndexShutdown),
        ("testIndexSwiftModules", testIndexSwiftModules),
        ("testInitJSON", testInitJSON),
        ("testInitLocal", testInitLocal),
    ]
}

extension SwiftCompileCommandsTest {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwiftCompileCommandsTest = [
        ("testNoWorkingDirectory", testNoWorkingDirectory),
        ("testPreexistingWorkingDirectoryArg", testPreexistingWorkingDirectoryArg),
        ("testWorkingDirectoryIsAdded", testWorkingDirectoryIsAdded),
    ]
}

extension SwiftCompletionTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwiftCompletionTests = [
        ("testCompletionClientFilter", testCompletionClientFilter),
        ("testCompletionDefaultFilter", testCompletionDefaultFilter),
        ("testCompletionOptional", testCompletionOptional),
        ("testCompletionOverride", testCompletionOverride),
        ("testCompletionOverrideInNewLine", testCompletionOverrideInNewLine),
        ("testCompletionPositionClientFilter", testCompletionPositionClientFilter),
        ("testCompletionPositionServerFilter", testCompletionPositionServerFilter),
        ("testCompletionServerFilter", testCompletionServerFilter),
        ("testCompletionSnippetSupport", testCompletionSnippetSupport),
        ("testMaxResults", testMaxResults),
        ("testRefilterAfterIncompleteResults", testRefilterAfterIncompleteResults),
        ("testRefilterAfterIncompleteResultsWithEdits", testRefilterAfterIncompleteResultsWithEdits),
        ("testSessionCloseWaitsforOpen", testSessionCloseWaitsforOpen),
    ]
}

extension SwiftPMIntegrationTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__SwiftPMIntegrationTests = [
        ("testSwiftPMIntegration", testSwiftPMIntegration),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BuildSystemTests.__allTests__BuildSystemTests),
        testCase(CodeActionTests.__allTests__CodeActionTests),
        testCase(DocumentColorTests.__allTests__DocumentColorTests),
        testCase(DocumentSymbolTest.__allTests__DocumentSymbolTest),
        testCase(ExecuteCommandTests.__allTests__ExecuteCommandTests),
        testCase(FoldingRangeTests.__allTests__FoldingRangeTests),
        testCase(ImplementationTests.__allTests__ImplementationTests),
        testCase(InlayHintsTests.__allTests__InlayHintsTests),
        testCase(LocalClangTests.__allTests__LocalClangTests),
        testCase(LocalSwiftTests.__allTests__LocalSwiftTests),
        testCase(MainFilesProviderTests.__allTests__MainFilesProviderTests),
        testCase(SKTests.__allTests__SKTests),
        testCase(SwiftCompileCommandsTest.__allTests__SwiftCompileCommandsTest),
        testCase(SwiftCompletionTests.__allTests__SwiftCompletionTests),
        testCase(SwiftPMIntegrationTests.__allTests__SwiftPMIntegrationTests),
    ]
}
#endif
