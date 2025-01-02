/*
 * URLStreamReaderTests.swift
 * StreamReader
 *
 * Created by François Lamboley on 2016/12/18.
 */

import Foundation
import XCTest

@testable import StreamReader



/* URLSessionStreamTask is not available (yet?) in public CoreFoundation. */
#if !canImport(FoundationNetworking)

class URLStreamReaderTests : XCTestCase {
	
	func testReadFromURLStream() throws {
		let group = DispatchGroup()
		let delegate = SessionDelegate(group)
		let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
		let dataTask = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
		
		group.enter()
		dataTask.resume()
		group.wait()
		
		let reader = URLSessionStreamTaskReader(stream: delegate.streamTask!, bufferSize: 1, bufferSizeIncrement: 1, readSizeLimit: nil, underlyingStreamReadSizeLimit: nil)
		XCTAssertEqual(try reader.readData(size: 1, allowReadingLess: false), Data("4".utf8))
		XCTAssertEqual(try reader.readData(size: 1, allowReadingLess: false), Data("2".utf8))
		XCTAssertThrowsError(try reader.readData(size: 1, allowReadingLess: false))
	}
	
	func testReadFromURLStreamAsInputStream() throws {
		let group = DispatchGroup()
		let delegate = SessionDelegate(group)
		let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
		let dataTask = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
		
		group.enter()
		dataTask.resume()
		group.wait()
		
		group.enter()
		delegate.streamTask!.captureStreams()
		group.wait()
		
		delegate.inputStream!.open()
		let reader = InputStreamReader(stream: delegate.inputStream!, bufferSize: 1, bufferSizeIncrement: 1, readSizeLimit: nil, underlyingStreamReadSizeLimit: nil)
		XCTAssertEqual(try reader.readData(size: 1, allowReadingLess: false), Data("4".utf8))
		XCTAssertEqual(try reader.readData(size: 1, allowReadingLess: false), Data("2".utf8))
		XCTAssertThrowsError(try reader.readData(size: 1, allowReadingLess: false))
	}
	
	/* Unsurprisingly, reading from the stream first from the task then from the input stream does not work.
	 * It has been observed that the InputStream retrieved after the read starts reading after an arbitrary number of bytes in the stream.
	 * It makes sense.
	 * Probably the stream task has an internal buffer.
	 * The first read would fill this buffer.
	 * Then we ask to convert the task stream to an InputStream which would be unaware of this buffer,
	 *  and thus has its reads start after said buffer.
	 * Another combination we could have checked, but that would probably fail too because the stream task and the InputStream seem mostly unaware of each other is:
	 *  getting the stream task, then getting the InputStream from it, then reading first from the stream task, then from the InputStream. */
//	func testReadFromURLStreamAndStreamAsInputStream() throws {
//		let group = DispatchGroup()
//		let delegate = SessionDelegate(group)
//		let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
//		let dataTask = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
//
//		group.enter()
//		dataTask.resume()
//		group.wait()
//
//		let reader1 = URLSessionStreamTaskReader(stream: delegate.streamTask!, bufferSize: 1, bufferSizeIncrement: 1, readSizeLimit: nil, underlyingStreamReadSizeLimit: nil)
//		XCTAssertEqual(try reader1.readData(size: 1, allowReadingLess: false), Data("4".utf8))
//
//		group.enter()
//		delegate.streamTask!.captureStreams()
//		group.wait()
//
//		delegate.inputStream!.open()
//		let reader2 = InputStreamReader(stream: delegate.inputStream!, bufferSize: 1, bufferSizeIncrement: 1, readSizeLimit: nil, underlyingStreamReadSizeLimit: nil)
//		XCTAssertEqual(try reader2.readData(size: 1, allowReadingLess: false), Data("2".utf8))
//		XCTAssertThrowsError(try reader2.readData(size: 1, allowReadingLess: false))
//	}
	
	/* This is not really Sendable, but we (probably) use it correctly… */
	fileprivate final class SessionDelegate : NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionStreamDelegate {
		
		let group: DispatchGroup
		
		var streamTask: URLSessionStreamTask?
		
		var inputStream: InputStream?
		var outputStream: OutputStream?
		
		init(_ group: DispatchGroup) {
			self.group = group
		}
		
		func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
			completionHandler(.becomeStream)
		}
		
		func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
			self.streamTask = streamTask
			group.leave()
		}
		
		func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
			self.inputStream = inputStream
			self.outputStream = outputStream
			group.leave()
		}
		
	}
	
}
#if swift(>=5.5)
extension URLStreamReaderTests.SessionDelegate : @unchecked Sendable {}
#endif

#endif
