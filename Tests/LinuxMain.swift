import XCTest

@testable import BufferStreamTests

var tests: [XCTestCaseEntry] = [
	testCase([
	]),
	testCase([
		("testReadSmallerThanBufferData", BufferStreamTests.testReadSmallerThanBufferData),
		("testReadBiggerThanBufferData", BufferStreamTests.testReadBiggerThanBufferData),
	]),
	testCase([
	]),
]
XCTMain(tests)
