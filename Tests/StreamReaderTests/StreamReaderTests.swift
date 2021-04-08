/*
 * StreamReaderTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 18/12/2016.
 */

import Foundation
import XCTest

import SystemPackage

@testable import StreamReader



class StreamReaderTests : XCTestCase {
	
	func testBasicUpToDelimiterRead() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let delim = Data(hexEncoded: "45")!
			
			let val = try reader.readData(upTo: [delim], matchingMode: .anyMatchWins, includeDelimiter: false)
			XCTAssertEqual(val.data, Data(hexEncoded: "01 23")!)
			XCTAssertEqual(val.delimiter, Data(hexEncoded: "45")!)
			XCTAssertEqual(try reader.readData(size: 1), Data(hexEncoded: "45")!)
			
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadToEnd() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readDataToEnd(), data)
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadToEndWithLimit() throws {
		try runTest(hexDataString: "01 23 45 67 89", readSizeLimits: Array(0...5), bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readDataToEnd(), data[0..<limit!])
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanStream() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertThrowsError(try reader.readData(size: 6))
			let rd = try reader.readData(size: 6, allowReadingLess: true)
			XCTAssertEqual(rd, data)
			
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testUpToWithSepInStreamAndOtherNotInStream() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let rd = try reader.readData(upTo: [Data(hexEncoded: "45 67")!, Data(hexEncoded: "89 75 45")!], matchingMode: .longestDataWins, includeDelimiter: true).data
			XCTAssertEqual(rd, data[0..<4])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testUpToWithSepsNotInStream() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertThrowsError(try reader.peekData(upTo: [Data(hexEncoded: "45 54")!, Data(hexEncoded: "89 75 45")!], matchingMode: .longestDataWins, includeDelimiter: true))
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadInt() throws {
		try runTest(hexDataString: "01 23 45 67", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let v: Int32 = try reader.readType()
			XCTAssertEqual(v, 1732584193)
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanLimit() throws {
		try runTest(hexDataString: "01 23 45 67 89", readSizeLimits: [3], bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertThrowsError(try reader.readData(size: 4))
			let rd1 = try reader.readData(size: 4, allowReadingLess: true)
			XCTAssertEqual(rd1, data[0..<3])
			
			reader.readSizeLimit = 2
			let rd2 = try reader.readData(size: 1, allowReadingLess: true)
			XCTAssertEqual(rd2, Data())
			
			reader.readSizeLimit = 3
			let rd3 = try reader.readData(size: 0, allowReadingLess: false)
			XCTAssertEqual(rd3, Data())
			
			reader.readSizeLimit = 2
			XCTAssertThrowsError(try reader.readData(size: 0, allowReadingLess: false))
			
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadToEndVariants() throws {
		let nonEmptyDataNotInStream = Data(hexEncoded: "02")!
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: true,  includeDelimiter: true).data, data)
			XCTAssertEqual(try reader.peekData(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, data)
			XCTAssertEqual(try reader.peekData(upTo: [Data()],                  matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, data)
			XCTAssertEqual(try reader.readData(upTo: [nonEmptyDataNotInStream], matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true).data, data)
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testPeekWithSize() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.peekData(size: 1), Data(hexEncoded: "01")!)
			XCTAssertEqual(try reader.peekData(size: 1), Data(hexEncoded: "01")!)
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testDataStreamPeekWithUpTo() throws {
		let sep = Data(hexEncoded: "23")!
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
			XCTAssertEqual(try reader.peekData(upTo: [sep], matchingMode: .anyMatchWins, includeDelimiter: false).data, Data(hexEncoded: "01")!)
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadExactlyToLimit() throws {
		try runTest(hexDataString: "01 23 45 67 89", readSizeLimits: Array(0...5), bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readData(size: limit!), data[0..<limit!])
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadSmallerThanBufferData() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(2...5), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readData(size: 2), data[0..<2])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanBufferData() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readData(size: 4), data[0..<4])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanBufferDataTwice() throws {
		try runTest(hexDataString: "01 23 45 67 89 01 23 45 67 89", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			XCTAssertEqual(try reader.readData(size: 4), data[0..<4])
			XCTAssertEqual(try reader.readData(size: 4), data[4..<8])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanBufferDataWithUpTo() throws {
		try runTest(hexDataString: "01 23 45 67 89", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let d = try reader.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
			XCTAssertEqual(d, data[0..<4])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanBufferDataWithUpToTwice() throws {
		try runTest(hexDataString: "01 23 45 67 89 01 23 45 67 89", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let d1 = try reader.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
			XCTAssertEqual(d1, data[0..<4])
			
			_ = try reader.readData(size: 1)
			
			let d2 = try reader.readData(upTo: [Data(hexEncoded: "89")!], matchingMode: .anyMatchWins, includeDelimiter: false).data
			XCTAssertEqual(d2, data[5..<9])
			
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadBiggerThanBufferDataWithUpToAndSmallestData() throws {
		try runTest(hexDataString: "01 23 45 67 89 98 76 54 32 10", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let d = try reader.readData(upTo: [Data(hexEncoded: "89")!, Data(hexEncoded: "98")!], matchingMode: .shortestDataWins, includeDelimiter: false).data
			XCTAssertEqual(d, data[0..<4])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testMatchingLongestData() throws {
		try runTest(hexDataString: "01 23 45 67 89 98 76 54 32 10", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let d = try reader.readData(upTo: [Data(hexEncoded: "89 98")!, Data(hexEncoded: "98")!, Data(hexEncoded: "76")!], matchingMode: .longestDataWins, includeDelimiter: true).data
			XCTAssertEqual(d, data[0..<7])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testMatchingFirstSepData() throws {
		try runTest(hexDataString: "01 23 45 67 89 98 76 54 32 10", bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			let d = try reader.readData(upTo: [Data(hexEncoded: "89 98")!, Data(hexEncoded: "98")!, Data(hexEncoded: "76")!], matchingMode: .firstMatchingDelimiterWins, includeDelimiter: false).data
			XCTAssertEqual(d, data[0..<4])
			XCTAssertFalse(try reader.checkForEOF())
			XCTAssertFalse(reader.hasReachedEOF)
		}
	}
	
	func testReadLine() throws {
		try runTest(string: "Hello World,\r\nHow are you\ntoday?\rHope you’re\n\rokay!", bufferSizes: Array(1...9), bufferSizeIncrements: Array(1...9), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			try checkReadLine(reader: reader, expectedLine: "Hello World,", expectedSeparator: "\r\n")
			try checkReadLine(reader: reader, expectedLine: "How are you", expectedSeparator: "\n")
			try checkReadLine(reader: reader, expectedLine: "today?", expectedSeparator: "\r")
			try checkReadLine(reader: reader, expectedLine: "Hope you’re", expectedSeparator: "\n")
			try checkReadLine(reader: reader, expectedLine: "", expectedSeparator: "\r")
			try checkReadLine(reader: reader, expectedLine: "okay!", expectedSeparator: "")
			XCTAssertNil(try reader.readLine(allowUnixNewLines: true, allowLegacyMacOSNewLines: true, allowWindowsNewLines: true))
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
		}
	}
	
	func testReadLine2() throws {
		struct DataToStrError : Error {}
		let str = """
		aa
		77y
		d
		d
		"""
		try runTest(string: str, bufferSizes: Array(1...4), bufferSizeIncrements: Array(1...5), underlyingStreamReadSizeLimits: [nil] + Array(1...9)){ reader, data, limit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit in
			var lines = [String]()
			while let (line, _) = try reader.readLine() {
				guard let lineStr = String(data: line, encoding: .utf8) else {
					throw DataToStrError()
				}
				lines.append(lineStr)
			}
			XCTAssertTrue(try reader.checkForEOF())
			XCTAssertTrue(reader.hasReachedEOF)
			XCTAssertEqual(lines, ["aa", "77y", "d", "d"])
		}
	}
	
	func testReadUnderlyingStream() throws {
		let data = Data(hexEncoded: "01 23 45 67 89")!
		
		for bufferSize in 1...4 {
			for bufferSizeIncrement in 1...5 {
				for allowMoreThanOneRead in [true, false] {
					let s = InputStream(data: data)
					s.open(); defer {s.close()}
					let readSizeLimit = 3
					let underlyingStreamReadSizeLimit = 2
					let reader = InputStreamReader(stream: s, bufferSize: bufferSize, bufferSizeIncrement: bufferSizeIncrement, readSizeLimit: readSizeLimit, underlyingStreamReadSizeLimit: underlyingStreamReadSizeLimit)
					XCTAssertEqual(try reader.readStreamInBuffer(size: 1, allowMoreThanOneRead: allowMoreThanOneRead), max(min(underlyingStreamReadSizeLimit, bufferSize), 1))
					XCTAssertEqual(try reader.readStreamInBuffer(size: 2, allowMoreThanOneRead: allowMoreThanOneRead), readSizeLimit - min(underlyingStreamReadSizeLimit, bufferSize))
				}
			}
		}
	}
	
	func testHasReachedEOF() throws {
		let data = Data(hexEncoded: "01 23 45 67 89")!
		
		let s = InputStream(data: data)
		s.open(); defer {s.close()}
		let reader = InputStreamReader(stream: s, bufferSize: 1, bufferSizeIncrement: 1, readSizeLimit: nil, underlyingStreamReadSizeLimit: nil)
		XCTAssertEqual(try reader.readStreamInBuffer(size: data.count, allowMoreThanOneRead: false), data.count)
		XCTAssertFalse(reader.hasReachedEOF)
		XCTAssertEqual(try reader.readStreamInBuffer(size: 1, allowMoreThanOneRead: false), 0)
		XCTAssertTrue(reader.hasReachedEOF)
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
	
	private func runTest(string: String, readSizeLimits: [Int?] = [nil], bufferSizes: [Int], bufferSizeIncrements: [Int], underlyingStreamReadSizeLimits: [Int?] = [nil], _ testHandler: (StreamReader, Data, Int?, Int?, Int?, Int?) throws -> Void) throws {
		try runTest(data: Data(string.utf8), readSizeLimits: readSizeLimits, bufferSizes: bufferSizes, bufferSizeIncrements: bufferSizeIncrements, underlyingStreamReadSizeLimits: underlyingStreamReadSizeLimits, testHandler)
	}
	
	private func runTest(hexDataString: String, readSizeLimits: [Int?] = [nil], bufferSizes: [Int], bufferSizeIncrements: [Int], underlyingStreamReadSizeLimits: [Int?] = [nil], _ testHandler: (StreamReader, Data, Int?, Int?, Int?, Int?) throws -> Void) throws {
		try runTest(data: Data(hexEncoded: hexDataString)!, readSizeLimits: readSizeLimits, bufferSizes: bufferSizes, bufferSizeIncrements: bufferSizeIncrements, underlyingStreamReadSizeLimits: underlyingStreamReadSizeLimits, testHandler)
	}
	
	private func runTest(data: Data, readSizeLimits: [Int?] = [nil], bufferSizes: [Int], bufferSizeIncrements: [Int], underlyingStreamReadSizeLimits: [Int?] = [nil], _ testHandler: (StreamReader, Data, Int?, Int?, Int?, Int?) throws -> Void) throws {
		for readSizeLimit in readSizeLimits {
			/* Test data reader */
			try testHandler(DataReader(data: data, readSizeLimit: readSizeLimit), data, readSizeLimit, nil, nil, nil)
			
			for bufferSize in bufferSizes {
				for bufferSizeIncrement in bufferSizeIncrements {
					for underlyingStreamReadSizeLimit in underlyingStreamReadSizeLimits {
						/* Test InputStream reader (from data) */
						let s = InputStream(data: data)
						s.open(); defer {s.close()}
						try testHandler(InputStreamReader(stream: s, bufferSize: bufferSize, bufferSizeIncrement: bufferSizeIncrement, readSizeLimit: readSizeLimit, underlyingStreamReadSizeLimit: underlyingStreamReadSizeLimit), data, readSizeLimit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit)
						
						let tmpFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("StreamReaderTest_\(Int.random(in: 0..<4242))")
						try data.write(to: tmpFileURL)
						defer {_ = try? FileManager.default.removeItem(at: tmpFileURL)}
						
						/* Test FileHandle reader (from file) */
						try testHandler(FileHandleReader(stream: FileHandle(forReadingFrom: tmpFileURL), bufferSize: bufferSize, bufferSizeIncrement: bufferSizeIncrement, readSizeLimit: readSizeLimit, underlyingStreamReadSizeLimit: underlyingStreamReadSizeLimit), data, readSizeLimit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit)
						
						let fd = try FileDescriptor.open(tmpFileURL.path, .readOnly)
						try fd.closeAfter{
							try testHandler(FileHandleReader(stream: fd, bufferSize: bufferSize, bufferSizeIncrement: bufferSizeIncrement, readSizeLimit: readSizeLimit, underlyingStreamReadSizeLimit: underlyingStreamReadSizeLimit), data, readSizeLimit, bufferSize, bufferSizeIncrement, underlyingStreamReadSizeLimit)
						}
					}
				}
			}
		}
	}
	
	private func checkReadLine(reader r: StreamReader, expectedLine: String, expectedSeparator: String) throws {
		let ret = try r.readLine(allowUnixNewLines: true, allowLegacyMacOSNewLines: true, allowWindowsNewLines: true)
		XCTAssertEqual(ret?.line, Data(expectedLine.utf8))
		XCTAssertEqual(ret?.newLineChars, Data(expectedSeparator.utf8))
	}
	
}
