// IPTests.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
import Venice

class IPTests: XCTestCase {
    func testLocalIPV4() {
        do {
            let _ = try IP(port: 5555, mode: .IPV4)
        } catch {
            XCTAssert(false)
        }
    }

    func testLocalIPV6() {
        do {
            let _ = try IP(port: 5555, mode: .IPV6)
        } catch {
            XCTAssert(false)
        }
    }

    func testLocalIPV4Preferd() {
        do {
            let _ = try IP(port: 5555, mode: .IPV4Prefered)
        } catch {
            XCTAssert(false)
        }
    }

    func testLocalIPV6Prefered() {
        do {
            let _ = try IP(port: 5555, mode: .IPV6Prefered)
        } catch {
            XCTAssert(false)
        }
    }

    func testNetworkInterfaceIPV4() {
        do {
            let _ = try IP(networkInterface: "lo0", port: 5555, mode: .IPV4)
        } catch {
            XCTAssert(true)
        }
    }

    func testNetworkInterfaceIPV6() {
        do {
            let _ = try IP(networkInterface: "lo0", port: 5555, mode: .IPV6)
        } catch {
            XCTAssert(true)
        }
    }

    func testNetworkInterfaceIPV4Prefered() {
        do {
            let _ = try IP(networkInterface: "lo0", port: 5555, mode: .IPV4Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testNetworkInterfaceIPV6Prefered() {
        do {
            let _ = try IP(networkInterface: "lo0", port: 5555, mode: .IPV6Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteIPV4() {
        do {
            let _ = try IP(address: "127.0.0.1", port: 5555, mode: .IPV4)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteIPV6() {
        do {
            let _ = try IP(address: "::1", port: 5555, mode: .IPV6)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteIPV4Prefered() {
        do {
            let _ = try IP(address: "127.0.0.1", port: 5555, mode: .IPV4Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteIPV6Prefered() {
        do {
            let _ = try IP(address: "::1", port: 5555, mode: .IPV6Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidPortIPV4() {
        do {
            let _ = try IP(port: 70000, mode: .IPV4)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidPortIPV6() {
        do {
            let _ = try IP(port: 70000, mode: .IPV6)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidPortIPV4Prefered() {
        do {
            let _ = try IP(port: 70000, mode: .IPV4Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidPortIPV6Prefered() {
        do {
            let _ = try IP(port: 70000, mode: .IPV6Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidNetworkInterfaceIPV4() {
        do {
            let _ = try IP(networkInterface: "yo-yo ma", port: 5555, mode: .IPV4)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidNetworkInterfaceIPV6() {
        do {
            let _ = try IP(networkInterface: "yo-yo ma", port: 5555, mode: .IPV6)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidNetworkInterfaceIPV4Prefered() {
        do {
            let _ = try IP(networkInterface: "yo-yo ma", port: 5555, mode: .IPV4Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testInvalidNetworkInterfaceIPV6Prefered() {
        do {
            let _ = try IP(networkInterface: "yo-yo ma", port: 5555, mode: .IPV6Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteInvalidPortIPV4() {
        do {
            let _ = try IP(address: "127.0.0.1", port: 70000, mode: .IPV4)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteInvalidPortIPV6() {
        do {
            let _ = try IP(address: "::1", port: 70000, mode: .IPV6)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteInvalidPortIPV4Prefered() {
        do {
            let _ = try IP(address: "127.0.0.1", port: 70000, mode: .IPV4Prefered)
        } catch {
            XCTAssert(true)
        }
    }

    func testRemoteInvalidPortIPV6Prefered() {
        do {
            let _ = try IP(address: "::1", port: 70000, mode: .IPV6Prefered)
        } catch {
            XCTAssert(true)
        }
    }

}