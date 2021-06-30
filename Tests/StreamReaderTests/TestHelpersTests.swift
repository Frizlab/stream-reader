/*
 * TestHelpersTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/3/27.
 */

import Foundation
import XCTest



class TestHelpersTests : XCTestCase {
	
	func testDataInitFromHexString() {
		XCTAssertEqual(Data(hexEncoded: "AB CD-12"), Data(hexEncoded: "ABCD12"))
		XCTAssertEqual(Data(hexEncoded: "AB CD-12"), Data([0xab, 0xcd, 0x12]))
	}
	
	func testDataInitFromHexDocCases() {
		XCTAssertEqual(Data(hexEncoded:   "FC"), Data([0xFC]))
		XCTAssertEqual(Data(hexEncoded:    "A"), Data([0x0A]))
		XCTAssertEqual(Data(hexEncoded:  "FCA"), Data([0xFC, 0x0A]))
		XCTAssertEqual(Data(hexEncoded: "FC0A"), Data([0xFC, 0x0A]))
		XCTAssertEqual(Data(hexEncoded:     ""), Data([]))
	}
	
}
