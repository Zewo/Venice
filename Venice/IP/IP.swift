// IP.swift
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

import libmill

public enum IPMode {
    case IPV4
    case IPV6
    case IPV4Prefered
    case IPV6Prefered
}

extension IPMode {
    var code: Int32 {
        switch self {
        case .IPV4: return 0
        case .IPV6: return 1
        case .IPV4Prefered: return 2
        case .IPV6Prefered: return 3
        }
    }
}

public struct IP {
    let address: ipaddr

    public init(port: Int, mode: IPMode = .IPV4) throws {
        self.address = iplocal(nil, Int32(port), mode.code)

        if errno != 0 {
            let description = IPError.lastSystemErrorDescription
            throw IPError(description: description)
        }
    }

    public init(local: String, port: Int, mode: IPMode = .IPV4) throws {
        self.address = iplocal(local, Int32(port), mode.code)

        if errno != 0 {
            let description = IPError.lastSystemErrorDescription
            throw IPError(description: description)
        }
    }

    public init(remote: String, port: Int, mode: IPMode = .IPV4, deadline: Deadline = NoDeadline) throws {
        self.address = ipremote(remote, Int32(port), mode.code, deadline)

        if errno != 0 {
            let description = IPError.lastSystemErrorDescription
            throw IPError(description: description)
        }
    }
}
