// Select.swift
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

protocol SelectCase {
    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int)
    func execute()
}

struct ChannelReceiveCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: T -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func execute() {
        let pointer = mill_choose_val(strideof(T))
        let value = channel.valueFromPointer(pointer)
        if let value = value {
            closure(value)
        }
    }
}

struct SendingChannelReceiveCase<T> : SelectCase {
    let channel: SendingChannel<T>
    let closure: T -> Void
    
    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel.channel, strideof(T), Int32(index))
    }
    
    func execute() {
        let pointer = mill_choose_val(strideof(T))
        let value = channel.valueFromPointer(pointer)
        if let value = value {
            closure(value)
        }
    }
}

struct FallibleChannelReceiveCase<T> : SelectCase {
    let channel: FallibleChannel<T>
    var closure: ChannelValue<T> -> Void

    func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel.channel, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() {
        let pointer = mill_choose_val(strideof(ChannelValue<T>))
        let result = channel.valueFromPointer(pointer)
        if let result = result {
            closure(result)
        }
    }
}

struct FallibleSendingChannelReceiveCase<T> : SelectCase {
    let channel: FallibleSendingChannel<T>
    var closure: ChannelValue<T> -> Void
    
    func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel.channel, strideof(ChannelValue<T>), Int32(index))
    }
    
    func execute() {
        let pointer = mill_choose_val(strideof(ChannelValue<T>))
        let result = channel.valueFromPointer(pointer)
        if let result = result {
            closure(result)
        }
    }
}

struct ChannelSendCase<T> : SelectCase {
    let channel: Channel<T>
    var value: T
    let closure: Void -> Void

    init(channel: Channel<T>, value: T, closure: Void -> Void) {
        self.channel = channel
        self.value = value
        self.closure = closure
    }

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_out(clause, channel.channel, &value, strideof(T), Int32(index))
    }

    func execute() {
        closure()
    }
}

struct ReceivingChannelSendCase<T> : SelectCase {
    let channel: ReceivingChannel<T>
    var value: T
    let closure: Void -> Void
    
    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_out(clause, channel.channel, &value, strideof(T), Int32(index))
    }
    
    func execute() {
        closure()
    }
}

struct FallibleChannelSendCase<T> : SelectCase {
    let channel: FallibleChannel<T>
    let value: T
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Value(self.value)
        mill_choose_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() {
        closure()
    }
}

struct FallibleReceivingChannelSendCase<T> : SelectCase {
    let channel: FallibleReceivingChannel<T>
    let value: T
    let closure: Void -> Void
    
    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Value(self.value)
        mill_choose_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }
    
    func execute() {
        closure()
    }
}

struct FallibleChannelSendErrorCase<T> : SelectCase {
    let channel: FallibleChannel<T>
    let error: ErrorType
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Error(self.error)
        mill_choose_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() {
        closure()
    }
}

struct FallibleReceivingChannelSendErrorCase<T> : SelectCase {
    let channel: FallibleReceivingChannel<T>
    let error: ErrorType
    let closure: Void -> Void
    
    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Error(self.error)
        mill_choose_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }
    
    func execute() {
        closure()
    }
}

struct TimeoutCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func execute() {
        closure()
    }
}

public class SelectCaseBuilder {
    var cases: [SelectCase] = []
    var otherwise: (Void -> Void)?

    public func receiveFrom<T>(channel: Channel<T>?, closure: T -> Void) {
        if let channel = channel {
            let patternCase = ChannelReceiveCase(channel: channel, closure: closure)
            cases.append(patternCase)
        }
    }
    
    public func receiveFrom<T>(channel: SendingChannel<T>?, closure: T -> Void) {
        if let channel = channel {
            let patternCase = SendingChannelReceiveCase(channel: channel, closure: closure)
            cases.append(patternCase)
        }
    }

    public func receiveFrom<T>(channel: FallibleChannel<T>?, closure: ChannelValue<T> -> Void) {
        if let channel = channel {
            let patternCase = FallibleChannelReceiveCase(channel: channel, closure: closure)
            cases.append(patternCase)
        }
    }
    
    public func receiveFrom<T>(channel: FallibleSendingChannel<T>?, closure: ChannelValue<T> -> Void) {
        if let channel = channel {
            let patternCase = FallibleSendingChannelReceiveCase(channel: channel, closure: closure)
            cases.append(patternCase)
        }
    }

    public func send<T>(value: T, to channel: Channel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = ChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(patternCase)
        }
    }
    
    public func send<T>(value: T, to channel: ReceivingChannel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = ReceivingChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(patternCase)
        }
    }

    public func send<T>(value: T, to channel: FallibleChannel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = FallibleChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(patternCase)
        }
    }
    
    public func send<T>(value: T, to channel: FallibleReceivingChannel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = FallibleReceivingChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(patternCase)
        }
    }

    public func throwError<T>(error: ErrorType, into channel: FallibleChannel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = FallibleChannelSendErrorCase(channel: channel, error: error, closure: closure)
            cases.append(patternCase)
        }
    }
    
    public func throwError<T>(error: ErrorType, into channel: FallibleReceivingChannel<T>?, closure: Void -> Void) {
        if let channel = channel where !channel.closed {
            let patternCase = FallibleReceivingChannelSendErrorCase(channel: channel, error: error, closure: closure)
            cases.append(patternCase)
        }
    }

    public func timeout(deadline: Int, closure: Void -> Void) {
        let done = Channel<Bool>()

        go {
            wakeUp(deadline)
            done <- true
        }

        let patternCase = TimeoutCase<Bool>(channel: done, closure: closure)
        cases.append(patternCase)
    }

    public func otherwise(closure: Void -> Void) {
        self.otherwise = closure
    }
}

public func select(build: SelectCaseBuilder -> Void) {
    let builder = SelectCaseBuilder()
    build(builder)
    mill_choose_init()

    var clausePointers: [UnsafeMutablePointer<Void>] = []

    for (index, var pattern) in builder.cases.enumerate() {
        let clausePointer = malloc(mill_clauselen())
        clausePointers.append(clausePointer)
        pattern.register(clausePointer, index: index)
    }

    if builder.otherwise != nil {
        mill_choose_otherwise()
    }

    let index = mill_choose_wait()
    
    if index == -1 {
        builder.otherwise?()
    } else {
        let selectCase = builder.cases[Int(index)]
        selectCase.execute()
    }
    
    for pointer in clausePointers {
        free(pointer)
    }
}

public func sel(build: SelectCaseBuilder -> Void) {
    select(build)
}