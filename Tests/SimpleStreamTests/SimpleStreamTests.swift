/*
 * SimpleStreamTests.swift
 * SimpleStream
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import XCTest
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
	
	func testDataStreamReadBiggerThanStream() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d)
		XCTAssertThrowsError(try ds.readData(size: 6))
		let rd = try ds.readData(size: 6, allowReadingLess: true)
		XCTAssert(rd == d)
	}
	
	func testDataStreamReadBiggerThanLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = SimpleDataStream(data: d, readSizeLimit: 3)
		XCTAssertThrowsError(try ds.readData(size: 4))
		let rd = try ds.readData(size: 4, allowReadingLess: true)
		XCTAssert(rd == d[0..<3])
	}
	
	func testReadBiggerThanStream() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		XCTAssertThrowsError(try bs.readData(size: 6))
		let rd = try bs.readData(size: 6, allowReadingLess: true)
		XCTAssert(rd == d)
	}
	
	func testReadBiggerThanLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1, readSizeLimit: 3)
		XCTAssertThrowsError(try bs.readData(size: 4))
		let rd = try bs.readData(size: 4, allowReadingLess: true)
		XCTAssert(rd == d[0..<3])
	}
	
	func testReadSmallerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d = try bs.readData(size: 2)
		XCTAssert(d == Data(hexEncoded: "01 23")!)
	}
	
	func testReadBiggerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = SimpleInputStream(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d = try bs.readData(size: 4)
		XCTAssert(d == Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadFromSimpleFileHandleStream() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("SimpleStreamTest_\(Int.random(in: 0..<4242))")
		let d = Data(hexEncoded: "01 23 45 67 89")!
		try d.write(to: tmpFileURL)
		defer {_ = try? FileManager.default.removeItem(at: tmpFileURL)}
		
		let stream = try SimpleFileHandleStream(stream: FileHandle(forReadingFrom: tmpFileURL), bufferSize: 3, bufferSizeIncrement: 3)
		let rd = try stream.readDataToEnd()
		XCTAssert(rd == d)
	}
	
	@available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *)
	func testReadErrorFromFileHandle() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("SimpleStreamTest_\(Int.random(in: 0..<4242))")
		XCTAssertTrue(FileManager.default.createFile(atPath: tmpFileURL.path, contents: Data(0..<127), attributes: nil))
		defer {_ = try? FileManager.default.removeItem(at: tmpFileURL)}
		
		let bufferSize = 3
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<UInt8>.alignment)
		defer {buffer.deallocate()}
		
		let fh = try FileHandle(forReadingFrom: tmpFileURL)
		try fh.close() /* Make the reads following this line fail on purpose */
		
		XCTAssertThrowsError(try fh.read(buffer, maxLength: bufferSize))
	}
	
}
