// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_assistant_intents",
    platforms: [
        .iOS("16.0"),
    ],
    products: [
        .library(name: "flutter-assistant-intents", targets: ["flutter_assistant_intents"]),
    ],
    targets: [
        .target(
            name: "flutter_assistant_intents",
            resources: []
        ),
    ]
)
