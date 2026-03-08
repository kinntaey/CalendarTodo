// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CalendarTodoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CalendarTodoCore",
            targets: ["CalendarTodoCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/auth0/JWTDecode.swift.git", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "CalendarTodoCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CalendarTodoCoreTests",
            dependencies: ["CalendarTodoCore"],
            path: "Tests"
        ),
    ]
)
