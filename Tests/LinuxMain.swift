import XCTest

@testable import SimpleStreamTests

var tests: [XCTestCaseEntry] = [
	testCase([
	]),
	testCase([
		("testReadSmallerThanBufferData", SimpleStreamTests.testReadSmallerThanBufferData),
		("testReadBiggerThanBufferData", SimpleStreamTests.testReadBiggerThanBufferData),
	]),
	testCase([
	]),
]
XCTMain(tests)
