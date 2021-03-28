/*
 * StreamReaderTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 18/12/2016.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation
import XCTest
@testable import StreamReader



class StreamReaderTests : XCTestCase {
	
	override func setUp() {
		super.setUp()
		
		/* Setup code goes here. */
	}
	
	override func tearDown() {
		/* Teardown code goes here. */
		
		super.tearDown()
	}
	
	func testDataStreamReadLine() throws {
		let r = DataReader(data: Data("Hello World,\r\nHow are you\ntoday?\rHope you’re\n\rokay!".utf8))
		try checkReadLine(reader: r, expectedLine: "Hello World,", expectedSeparator: "\r\n")
		try checkReadLine(reader: r, expectedLine: "How are you", expectedSeparator: "\n")
		try checkReadLine(reader: r, expectedLine: "today?", expectedSeparator: "\r")
		try checkReadLine(reader: r, expectedLine: "Hope you’re", expectedSeparator: "\n")
		try checkReadLine(reader: r, expectedLine: "", expectedSeparator: "\r")
		try checkReadLine(reader: r, expectedLine: "okay!", expectedSeparator: "")
		XCTAssertNil(try r.readLine(allowUnixNewLines: true, allowLegacyMacOSNewLines: true, allowWindowsNewLines: true))
	}
	
	func testDataStreamBasicUpToDelimiterRead() throws {
		let delim = Data(hexEncoded: "45")!
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d)
		let rd = try ds.readData(upTo: [delim], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssertEqual(rd, Data(hexEncoded: "01 23")!)
		
		let nx = try ds.readData(size: 1)
		XCTAssertEqual(nx, Data(hexEncoded: "45")!)
	}
	
	func testDataStreamReadToEnd() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d)
		let rd = try ds.readDataToEnd()
		XCTAssertEqual(rd, d)
	}
	
	func testDataStreamReadToEndWithLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d, readSizeLimit: 3)
		let rd = try ds.readDataToEnd()
		XCTAssertEqual(rd, d[0..<3])
	}
	
	func testDataStreamReadBiggerThanStream() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d)
		XCTAssertThrowsError(try ds.readData(size: 6))
		let rd = try ds.readData(size: 6, allowReadingLess: true)
		XCTAssertEqual(rd, d)
	}
	
	func testDataStreamReadBiggerThanLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d, readSizeLimit: 3)
		XCTAssertThrowsError(try ds.readData(size: 4))
		let rd = try ds.readData(size: 4, allowReadingLess: true)
		XCTAssertEqual(rd, d[0..<3])
		
		ds.readSizeLimit = 2
		let rd2 = try ds.readData(size: 1, allowReadingLess: true)
		XCTAssertEqual(rd2, Data())
		
		ds.readSizeLimit = 3
		let rd3 = try ds.readData(size: 0, allowReadingLess: false)
		XCTAssertEqual(rd3, Data())
	}
	
	func testDataStreamReadToEndVariants() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let nonEmptyDataNotInStream = Data(hexEncoded: "02")!
		
		XCTAssertEqual(try DataReader(data: d).peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: true,  includeDelimiter: true).data, d)
		XCTAssertEqual(try DataReader(data: d).peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
		XCTAssertEqual(try DataReader(data: d).peekData(upTo: [Data()],                  matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
		XCTAssertEqual(try DataReader(data: d).peekData(upTo: [nonEmptyDataNotInStream], matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
	}
	
	func testDataStreamPeekWithSize() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = DataReader(data: d)
		XCTAssertEqual(try s.peekData(size: 1), Data(hexEncoded: "01")!)
		XCTAssertEqual(try s.peekData(size: 1), Data(hexEncoded: "01")!)
	}
	
	func testDataStreamPeekWithUpTo() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let sep = Data(hexEncoded: "23")!
		
		let s = DataReader(data: d)
		XCTAssertEqual(try s.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
		XCTAssertEqual(try s.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
	}
	
	func testDataStreamReadExactlyToLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let ds = DataReader(data: d, readSizeLimit: 1)
		let rd = try ds.readData(size: 1)
		XCTAssertEqual(rd, d[0..<1])
	}
	
	func testStreamReadExactlyToLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2, readSizeLimit: 1)
		let rd = try reader.readData(size: 1)
		XCTAssertEqual(rd, d[0..<1])
	}
	
	func testStreamReadToEnd() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2)
		let rd = try reader.readDataToEnd()
		XCTAssertEqual(rd, d)
	}
	
	func testStreamReadLine() throws {
		let s = InputStream(data: Data("Hello World,\r\nHow are you\ntoday?\rHope you’re\n\rokay!".utf8))
		s.open(); defer {s.close()}
		
		let r = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2)
		try checkReadLine(reader: r, expectedLine: "Hello World,", expectedSeparator: "\r\n")
		try checkReadLine(reader: r, expectedLine: "How are you", expectedSeparator: "\n")
		try checkReadLine(reader: r, expectedLine: "today?", expectedSeparator: "\r")
		try checkReadLine(reader: r, expectedLine: "Hope you’re", expectedSeparator: "\n")
		try checkReadLine(reader: r, expectedLine: "", expectedSeparator: "\r")
		try checkReadLine(reader: r, expectedLine: "okay!", expectedSeparator: "")
		XCTAssertNil(try r.readLine(allowUnixNewLines: true, allowLegacyMacOSNewLines: true, allowWindowsNewLines: true))
	}
	
	func testStreamReadToEndWithLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2, readSizeLimit: 1)
		let rd = try reader.readDataToEnd()
		XCTAssertEqual(rd, d[0..<1])
	}
	
	func testStreamReadToEndVariants() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let nonEmptyDataNotInStream = Data(hexEncoded: "02")!
		
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 1, bufferSizeIncrement: 1)
		XCTAssertEqual(try reader.peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: true,  includeDelimiter: true).data, d)
		XCTAssertEqual(try reader.peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
		XCTAssertEqual(try reader.peekData(upTo: [Data()],                  matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
		XCTAssertEqual(try reader.peekData(upTo: [nonEmptyDataNotInStream], matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, d)
	}
	
	func testStreamPeekWithSize() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 1, bufferSizeIncrement: 1)
		XCTAssertEqual(try reader .peekData(size: 1), Data(hexEncoded: "01")!)
		XCTAssertEqual(try reader .peekData(size: 1), Data(hexEncoded: "01")!)
	}
	
	func testStreamPeekWithUpTo() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let sep = Data(hexEncoded: "23")!
		
		let s = DataReader(data: d)
		XCTAssertEqual(try s.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
		XCTAssertEqual(try s.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
	}
	
	func testReadBiggerThanStream() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		XCTAssertThrowsError(try bs.readData(size: 6))
		let rd = try bs.readData(size: 6, allowReadingLess: true)
		XCTAssertEqual(rd, d)
	}
	
	func testReadBiggerThanLimit() throws {
		let d = Data(hexEncoded: "01 23 45 67 89")!
		let s = InputStream(data: d)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1, readSizeLimit: 3)
		XCTAssertThrowsError(try bs.readData(size: 4))
		let rd = try bs.readData(size: 4, allowReadingLess: true)
		XCTAssertEqual(rd, d[0..<3])
	}
	
	func testReadSmallerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d = try bs.readData(size: 2)
		XCTAssertEqual(d, Data(hexEncoded: "01 23")!)
	}
	
	func testReadBiggerThanBufferData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d = try bs.readData(size: 4)
		XCTAssertEqual(d, Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadBiggerThanBufferDataTwice() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89 01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2)
		let d1 = try bs.readData(size: 4)
		XCTAssertEqual(d1, Data(hexEncoded: "01 23 45 67")!)
		let d2 = try bs.readData(size: 4)
		XCTAssertEqual(d2, Data(hexEncoded: "89 01 23 45")!)
	}
	
	func testReadBiggerThanBufferDataWithUpTo() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d = try bs.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssertEqual(d, Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadBiggerThanBufferDataWithUpToTwice() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89 01 23 45 67 89")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 1)
		let d1 = try bs.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssertEqual(d1, Data(hexEncoded: "01 23 45 67")!)
		_ = try bs.readData(size: 1)
		let d2 = try bs.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
		XCTAssertEqual(d2, Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadBiggerThanBufferDataWithUpToAndSmallestData() throws {
		let s = InputStream(data: Data(hexEncoded: "01 23 45 67 89 98 76 54 32 10")!)
		s.open(); defer {s.close()}
		
		let bs = InputStreamReader(stream: s, bufferSize: 3, bufferSizeIncrement: 2)
		let d = try bs.readData(upTo: [Data(hexEncoded: "89")!, Data(hexEncoded: "98")!], matchingMode: .shortestDataWins, includeDelimiter: false).data
		XCTAssertEqual(d, Data(hexEncoded: "01 23 45 67")!)
	}
	
	func testReadFromFileHandleReader() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("StreamReaderTest_\(Int.random(in: 0..<4242))")
		let d = Data(hexEncoded: "01 23 45 67 89")!
		try d.write(to: tmpFileURL)
		defer {_ = try? FileManager.default.removeItem(at: tmpFileURL)}
		
		let stream = try FileHandleReader(stream: FileHandle(forReadingFrom: tmpFileURL), bufferSize: 3, bufferSizeIncrement: 3)
		let rd = try stream.readDataToEnd()
		XCTAssertEqual(rd, d)
	}
	
	@available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *)
	func testReadErrorFromFileHandle() throws {
		let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("StreamReaderTest_\(Int.random(in: 0..<4242))")
		XCTAssertTrue(FileManager.default.createFile(atPath: tmpFileURL.path, contents: Data(0..<127), attributes: nil))
		defer {_ = try? FileManager.default.removeItem(at: tmpFileURL)}
		
		let bufferSize = 3
		let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<UInt8>.alignment)
		defer {buffer.deallocate()}
		
		let fh = try FileHandle(forReadingFrom: tmpFileURL)
		try fh.close() /* Make the reads following this line fail on purpose */
		
		XCTAssertThrowsError(try fh.read(buffer, maxLength: bufferSize))
	}
	
	private func checkReadLine(reader r: StreamReader, expectedLine: String, expectedSeparator: String) throws {
		let ret = try r.readLine(allowUnixNewLines: true, allowLegacyMacOSNewLines: true, allowWindowsNewLines: true)
		XCTAssertEqual(ret?.line, Data(expectedLine.utf8))
		XCTAssertEqual(ret?.newLineChars, Data(expectedSeparator.utf8))
	}
	
}
