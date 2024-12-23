// swift-tools-version:5.8
import PackageDescription


/* For Swift 5.2 and 5.3, it is not allowed to have an empty Swift settings array.
 * I _think_ it does not matter anyway, we have to create a package specifically for Swift 5.8 and above as the option seems to be ignored otherwise. */
let swiftSettings: [SwiftSetting] = [
	.enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	targets: [
		.target(name: "StreamReader", swiftSettings: swiftSettings),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"], swiftSettings: swiftSettings)
	]
)
