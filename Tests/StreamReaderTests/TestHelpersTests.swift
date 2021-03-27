/*
 * TestHelpersTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/3/27.
 * Copyright © 2021 frizlab. All rights reserved.
 */

import Foundation
import XCTest



class TestHelpersTests : XCTestCase {
	
	func testDataInitFromHexString() {
		XCTAssertEqual(Data(hexEncoded: "AB CD-12"), Data(hexEncoded: "ABCD12"))
		XCTAssertEqual(Data(hexEncoded: "AB CD-12"), Data([0xab, 0xcd, 0x12]))
	}
	
}
