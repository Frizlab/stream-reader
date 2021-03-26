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
	
	func testDataStreamBasicUpToDelimiterRead() throws {
		let delim = Data(hexEncoded: "45")!
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d)
		let rd = try ds.readData(upTo: [delim], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssert(rd == Data(hexEncoded: "01 23")!)
		
		let nx = try ds.readData(size: 1)
		XCTAssert(nx == Data(hexEncoded: "45")!)
	}
	
	func testDataStreamReadToEnd() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d)
		let rd = try ds.readDataToEnd()
		XCTAssert(rd == d)
	}
	
	func testReadSmallerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1, streamReadSizeLimit: nil)
		let d = try bs.readData(size: 2)
		XCTAssert(d == Data(hexEncoded: "01 23")!)
	}

	func testReadBiggerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1, streamReadSizeLimit: nil)
		let d = try bs.readData(size: 4)
		XCTAssert(d == Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadFromSimpleFileHandleStream() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("SimpleStreamTest_\(Int.random(in: 0..<4242))")
		let d = Data(hexEncoded: "01 23 45 67 89")!
		try d.write(to: tmpFileURL)
		
		let stream = try SimpleFileHandleStream(stream: FileHandle(forReadingFrom: tmpFileURL), bufferSize: 3, bufferSizeIncrement: 3, streamReadSizeLimit: nil)
		let rd = try stream.readDataToEnd()
		XCTAssert(rd == d)
	}
	
	@available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *)
	func testReadErrorFromFileHandle() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("SimpleStreamTest_\(Int.random(in: 0..<4242))")
		XCTAssertTrue(FileManager.default.createFile(atPath: tmpFileURL.path, contents: Data(0..<127), attributes: nil))
		
		let bufferSize = 3
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<UInt8>.alignment)
		defer {buffer.deallocate()}
		
		let fh = try FileHandle(forReadingFrom: tmpFileURL)
		try fh.close() /* Make the reads following this line fail on purpose */
		
		XCTAssertThrowsError(try fh.read(buffer, maxLength: bufferSize))
	}
	
}
