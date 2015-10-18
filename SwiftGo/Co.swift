// Go.swift
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

import Libmill

/// Current time
public var now: Int {
    return Int(Libmill.now())
}

public let hour = 3600000
public let minute = 60000
public let second = 1000
public let millisecond = 1

/// Runs the expression in a lightweight coroutine
public func go(@autoclosure(escaping) routine: Void -> Void) {
    Libmill.go(routine)
}

/// Runs the expression in a lightweight coroutine
public func go(routine: Void -> Void) {
    Libmill.go(routine)
}

/// Runs the expression in a lightweight coroutine
public func goAfter(napDuration: Int, routine: Void -> Void) {
    Libmill.go {
        nap(napDuration)
        routine()
    }
}

/// Preallocates coroutine stacks. Returns the number of stacks that it actually managed to allocate.
public func preallocateCoroutineStacks(stackCount stackCount: Int, stackSize: Int, channelValueMaxSize: Int) -> Int {
    return Int(goprepare(Int32(stackCount), stackSize, channelValueMaxSize))
}

/// Sleeps for duration
public func nap(duration: Int) {
    mill_msleep(Int64(now + duration))
}

/// Wakes up at deadline
public func wakeUp(deadline: Int) {
    mill_msleep(Int64(deadline))
}

/// Passes control to other coroutines
public var yield: Void {
    mill_yield()
}

public struct PollEvent : OptionSetType {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let Read  = PollEvent(rawValue: 1)
    public static let Write = PollEvent(rawValue: 2)
}

public struct PollResult : OptionSetType {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let Timeout = PollResult(rawValue: 0)
    public static let Read    = PollResult(rawValue: 1)
    public static let Write   = PollResult(rawValue: 2)
    public static let Error   = PollResult(rawValue: 4)
}

/// Polls file descriptor for events
public func pollFileDescriptor(fileDescriptor: Int32, events: PollEvent, deadline: Int = -1) -> PollResult {
    let event = mill_fdwait(fileDescriptor, events.rawValue, Int64(deadline))
    return PollResult(rawValue: event)
}