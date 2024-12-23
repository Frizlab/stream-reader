// swift-tools-version:5.2
import PackageDescription


let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	targets: [
		.target(name: "StreamReader"),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"])
	]
)
