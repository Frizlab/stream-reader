/*
 * SimpleStreamTests.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import XCTest
import Foundation
@testable import SimpleStream



class SimpleStreamTests : XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		/* Setup code goes here. */
	}
	
	override func tearDown() {
		/* Teardown code goes here. */
		
		super.tearDown()
	}
	
	func testDataStreamBasicUpToDelimiterRead() {
		let delim = Data(hexEncoded: "45")!
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d)
		let rd = try? ds.readData(upTo: [delim], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssert(rd == Data(hexEncoded: "01 23")!)
	}
	
	func testDataStreamReadToEnd() {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d)
		let rd = try? ds.readDataToEnd()
		XCTAssert(rd == d)
	}
	
//	func testReadSmallerThanBufferData() {
//		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
//		s.open(); defer {s.close()}
//
//		let bs = SimpleInputStream(stream: s, bufferSize: 3, streamReadSizeLimit: nil)
//		let d = try? bs.readData(size: 2, alwaysCopyBytes: false)
//		XCTAssert(d == Data(hexEncoded: "01 23")!)
//	}
//
//	func testReadBiggerThanBufferData() {
//		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
//		s.open(); defer {s.close()}
//
//		let bs = SimpleInputStream(stream: s, bufferSize: 3, streamReadSizeLimit: nil)
//		let d = try? bs.readData(size: 4, alwaysCopyBytes: false)
//		XCTAssert(d == Data(hexEncoded: "01 23 45 67")!)
//	}
	
}
