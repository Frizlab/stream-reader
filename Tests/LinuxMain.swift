import XCTest

@testable import StreamReaderTests

var tests: [XCTestCaseEntry] = [
  testCase([
  ]),
  testCase([
            ("testDelimitersCleanupForShortestDataWithoutDelimiter", MatchingTests.testDelimitersCleanupForShortestDataWithoutDelimiter),
            ("testDelimitersCleanupForLongestDataWithDelimiter", MatchingTests.testDelimitersCleanupForLongestDataWithDelimiter),
  ]),
  testCase([
            ("testBasicUpToDelimiterRead", StreamReaderTests.testBasicUpToDelimiterRead),
            ("testReadToEnd", StreamReaderTests.testReadToEnd),
            ("testReadToEndWithLimit", StreamReaderTests.testReadToEndWithLimit),
            ("testReadBiggerThanStream", StreamReaderTests.testReadBiggerThanStream),
            ("testUpToWithSepInStreamAndOtherNotInStream", StreamReaderTests.testUpToWithSepInStreamAndOtherNotInStream),
            ("testUpToWithSepsNotInStream", StreamReaderTests.testUpToWithSepsNotInStream),
            ("testUpToWithSepBiggerThanBufferWODelimiter", StreamReaderTests.testUpToWithSepBiggerThanBufferWODelimiter),
            ("testUpToWithSepBiggerThanBufferWDelimiter", StreamReaderTests.testUpToWithSepBiggerThanBufferWDelimiter),
            ("testUpToMatchingMinLength", StreamReaderTests.testUpToMatchingMinLength),
            ("testUpToWithWithOverlappingSeps", StreamReaderTests.testUpToWithWithOverlappingSeps),
            ("testUpToFirstMatchingWinsMultipleCandidates", StreamReaderTests.testUpToFirstMatchingWinsMultipleCandidates),
            ("testReadInt", StreamReaderTests.testReadInt),
            ("testReadBiggerThanLimit", StreamReaderTests.testReadBiggerThanLimit),
            ("testReadToEndVariants", StreamReaderTests.testReadToEndVariants),
            ("testPeekWithSize", StreamReaderTests.testPeekWithSize),
            ("testDataStreamPeekWithUpTo", StreamReaderTests.testDataStreamPeekWithUpTo),
            ("testReadExactlyToLimit", StreamReaderTests.testReadExactlyToLimit),
            ("testReadSmallerThanBufferData", StreamReaderTests.testReadSmallerThanBufferData),
            ("testReadBiggerThanBufferData", StreamReaderTests.testReadBiggerThanBufferData),
            ("testReadBiggerThanBufferDataTwice", StreamReaderTests.testReadBiggerThanBufferDataTwice),
            ("testReadBiggerThanBufferDataWithUpTo", StreamReaderTests.testReadBiggerThanBufferDataWithUpTo),
            ("testReadBiggerThanBufferDataWithUpToTwice", StreamReaderTests.testReadBiggerThanBufferDataWithUpToTwice),
            ("testReadBiggerThanBufferDataWithUpToAndSmallestData", StreamReaderTests.testReadBiggerThanBufferDataWithUpToAndSmallestData),
            ("testMatchingLongestData", StreamReaderTests.testMatchingLongestData),
            ("testMatchingFirstSepData", StreamReaderTests.testMatchingFirstSepData),
            ("testReadLine", StreamReaderTests.testReadLine),
            ("testReadLine2", StreamReaderTests.testReadLine2),
            ("testReadLine3", StreamReaderTests.testReadLine3),
            ("testReadUpToWhenUnderlyingStreamHasEOF", StreamReaderTests.testReadUpToWhenUnderlyingStreamHasEOF),
            ("testReadUpToWhenUnderlyingStreamHasEOFVirtually", StreamReaderTests.testReadUpToWhenUnderlyingStreamHasEOFVirtually),
            ("testReadUnderlyingStream", StreamReaderTests.testReadUnderlyingStream),
            ("testStreamHasReachedEOF", StreamReaderTests.testStreamHasReachedEOF),
            ("testReadInBufferThenLimitReadThenReadUpTo", StreamReaderTests.testReadInBufferThenLimitReadThenReadUpTo),
            ("testReadLimitFromDoc", StreamReaderTests.testReadLimitFromDoc),
            ("testAllowedToBeReadLowerThan0", StreamReaderTests.testAllowedToBeReadLowerThan0),
            ("testReadErrorFromFileHandle", StreamReaderTests.testReadErrorFromFileHandle),
  ]),
  testCase([
  ]),
  testCase([
            ("testDataInitFromHexString", TestHelpersTests.testDataInitFromHexString),
            ("testDataInitFromHexDocCases", TestHelpersTests.testDataInitFromHexDocCases),
  ]),
  testCase([
            ("testReadFromURLStream", URLStreamReaderTests.testReadFromURLStream),
            ("testReadFromURLStreamAsInputStream", URLStreamReaderTests.testReadFromURLStreamAsInputStream),
            ("testReadFromURLStreamAndStreamAsInputStream", URLStreamReaderTests.testReadFromURLStreamAndStreamAsInputStream),
  ]),
  testCase([
  ]),
]
XCTMain(tests)
