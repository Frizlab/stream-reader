/*
 * MatchingTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 2022/09/14.
 */

import Foundation
import XCTest

@testable import StreamReader



class MatchingTests : XCTestCase {
	
	func testDelimitersCleanupForShortestDataWithoutDelimiter() {
		XCTAssertEqual(
			cleanupDelimiters([Data(), Data(hexEncoded: "01")!, Data(hexEncoded: "01 02")!, Data(hexEncoded: "01 02")!, Data(hexEncoded: "02")!], forMatchingMode: .shortestDataWins, includingDelimiter: false),
			[Data(), Data(hexEncoded: "01")!, Data(hexEncoded: "02")!]
		)
	}
	
	func testDelimitersCleanupForLongestDataWithDelimiter() {
		XCTAssertEqual(
			cleanupDelimiters([Data(), Data(hexEncoded: "01")!, Data(hexEncoded: "01 02")!, Data(hexEncoded: "01 02")!, Data(hexEncoded: "02")!, Data(hexEncoded: "01")!], forMatchingMode: .longestDataWins, includingDelimiter: true),
			[Data(), Data(hexEncoded: "01")!, Data(hexEncoded: "02")!]
		)
	}
	
}
