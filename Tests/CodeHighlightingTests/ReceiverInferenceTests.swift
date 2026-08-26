//
//  ReceiverInferenceTests.swift
//  Tests for SwiftCodeHighlighting
//
//  The receiver-typing tier is pure string/array logic (no tree-sitter), so
//  unlike the grammar queries it CAN be exercised under XCTest. Every case was
//  mutation-verified: run with the function under test disabled and it fails.
//

import XCTest
@testable import CodeHighlighting

final class ReceiverInferenceTests: XCTestCase {

    // MARK: - receiver(before:in:)

    private func rcv(_ code: String, wordStart: Int) -> String? {
        ReceiverInference.receiver(before: wordStart, in: code as NSString)
    }

    func testReceiverAcrossOperators() {
        let php = "$obj->my_method()"          // word starts at 6
        XCTAssertEqual(rcv(php, wordStart: 6), "$obj")
        let scoped = "Limits::MAX_BATCH"       // word starts at 8
        XCTAssertEqual(rcv(scoped, wordStart: 8), "Limits")
        let dot = "signer.sign()"              // word starts at 7
        XCTAssertEqual(rcv(dot, wordStart: 7), "signer")
    }

    func testReceiverOfChainedAccessIsTheNearestSegment() {
        let code = "$this->signer->sign()"     // "sign" starts at 15
        XCTAssertEqual(rcv(code, wordStart: 15), "signer")
    }

    func testNoReceiverForPlainCall() {
        XCTAssertNil(rcv("render_pipeline()", wordStart: 0))
        XCTAssertNil(rcv("  foo()", wordStart: 2))   // whitespace before, no operator
    }

    // MARK: - isSelfReference

    func testSelfReferenceSpellings() {
        for t in ["$this", "this", "self", "cls", "static"] {
            XCTAssertTrue(ReceiverInference.isSelfReference(t), t)
        }
        XCTAssertFalse(ReceiverInference.isSelfReference("$obj"))
        XCTAssertFalse(ReceiverInference.isSelfReference("Signer"))
    }

    // MARK: - inferredType(of:near:in:)

    func testPHPNewAssignment() {
        let code = "$signer = new CryptoSigner();\n$signer->sign();"
        XCTAssertEqual(ReceiverInference.inferredType(of: "$signer", near: 40, in: code), "CryptoSigner")
    }

    func testPHPQualifiedNewCollapsesToBareName() {
        let code = "$out = new \\FreshlyVault\\Crypto\\Signer();\n$out->sign();"
        XCTAssertEqual(ReceiverInference.inferredType(of: "$out", near: 50, in: code), "Signer")
    }

    func testPHPTypedParameterAndProperty() {
        let param = "function f(CryptoSigner $signer) { $signer->sign(); }"
        XCTAssertEqual(ReceiverInference.inferredType(of: "$signer", near: 40, in: param), "CryptoSigner")
        let prop = "private CryptoSigner $signer;"
        XCTAssertEqual(ReceiverInference.inferredType(of: "$signer", near: 0, in: prop), "CryptoSigner")
    }

    func testTSAnnotationAndNew() {
        let ann = "const signer: CryptoSigner = make();\nsigner.sign();"
        XCTAssertEqual(ReceiverInference.inferredType(of: "signer", near: 45, in: ann), "CryptoSigner")
        let newed = "let signer = new CryptoSigner();\nsigner.sign();"
        XCTAssertEqual(ReceiverInference.inferredType(of: "signer", near: 40, in: newed), "CryptoSigner")
    }

    func testLowercaseTypesAreRejected() {
        // Primitives and keywords must not read as classes.
        XCTAssertNil(ReceiverInference.inferredType(of: "signer", near: 30, in: "const signer: string = '';\nsigner.at(0);"))
        XCTAssertNil(ReceiverInference.inferredType(of: "$signer", near: 20, in: "return $signer;\n$signer->sign();"))
    }

    func testNearestPrecedingBindingWins() {
        let code = """
        $x = new First();
        $x = new Second();
        $x->go();
        $x = new Third();
        """
        // Caret in `$x->go()` (~line 3): the Second() assignment is the live one.
        let caret = (code as NSString).range(of: "go").location
        XCTAssertEqual(ReceiverInference.inferredType(of: "$x", near: caret, in: code), "Second")
    }

    func testBindingAfterCaretIsUsedWhenNonePrecedes() {
        let code = "$this->signer->sign();\nprivate CryptoSigner $signer;"
        XCTAssertEqual(ReceiverInference.inferredType(of: "$signer", near: 8, in: code), "CryptoSigner")
    }

    // MARK: - looksLikeTypeName / bareName

    func testTypeNameShape() {
        XCTAssertTrue(ReceiverInference.looksLikeTypeName("Limits"))
        XCTAssertFalse(ReceiverInference.looksLikeTypeName("signer"))
        XCTAssertFalse(ReceiverInference.looksLikeTypeName("$Signer"))
        XCTAssertEqual(ReceiverInference.bareName("\\Foo\\Bar\\Signer"), "Signer")
        XCTAssertEqual(ReceiverInference.bareName("pkg.Signer"), "Signer")
        XCTAssertEqual(ReceiverInference.bareName("Signer"), "Signer")
    }

    // MARK: - SymbolOwners

    private func sym(_ name: String, _ kind: SymbolKind, at loc: Int, scope: NSRange? = nil) -> Symbol {
        Symbol(name: name, kind: kind, range: NSRange(location: loc, length: name.count),
               line: 1, scopeRange: scope)
    }

    func testOwnerIsTheEnclosingClass() {
        let syms = [
            sym("Signer", .type, at: 10, scope: NSRange(location: 0, length: 100)),
            sym("sign", .method, at: 40),
            sym("Pipeline", .type, at: 210, scope: NSRange(location: 200, length: 100)),
            sym("sign", .method, at: 240),
            sym("free_fn", .function, at: 400),
        ]
        let owners = SymbolOwners.owners(in: syms)
        XCTAssertEqual(owners[1], "Signer")
        XCTAssertEqual(owners[3], "Pipeline")
        XCTAssertNil(owners[4])     // free function has no owner
        XCTAssertNil(owners[0])     // a type owns itself → no owner entry
    }

    func testInnermostTypeWinsForNestedScopes() {
        let syms = [
            sym("Outer", .type, at: 0, scope: NSRange(location: 0, length: 1000)),
            sym("Inner", .type, at: 100, scope: NSRange(location: 100, length: 200)),
            sym("m", .method, at: 150),
        ]
        XCTAssertEqual(SymbolOwners.owners(in: syms)[2], "Inner")
    }

    func testEnclosingTypeAtCaret() {
        let syms = [
            sym("Pipeline", .type, at: 10, scope: NSRange(location: 0, length: 500)),
        ]
        XCTAssertEqual(SymbolOwners.enclosingType(of: NSRange(location: 250, length: 3), in: syms), "Pipeline")
        XCTAssertNil(SymbolOwners.enclosingType(of: NSRange(location: 600, length: 3), in: syms))
    }
}
