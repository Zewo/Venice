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

import CLibvenice

protocol SelectCase {
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int)
    func execute()
}

final class ChannelReceiveCase<T>: SelectCase {
    let channel: Channel<T>
    let closure: (T) -> Void

    init(channel: Channel<T>, closure: (T) -> Void) {
        self.channel = channel
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.registerReceive(clause, index: index)
    }

    func execute() {
        if let value = channel.getValueFromBuffer() {
            closure(value)
        }
    }
}

final class ReceivingChannelReceiveCase<T>: SelectCase {
    let channel: ReceivingChannel<T>
    let closure: (T) -> Void

    init(channel: ReceivingChannel<T>, closure: (T) -> Void) {
        self.channel = channel
        self.closure = closure
    }
    
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.registerReceive(clause, index: index)
    }
    
    func execute() {
        if let value = channel.getValueFromBuffer() {
            closure(value)
        }
    }
}

final class FallibleChannelReceiveCase<T>: SelectCase {
    let channel: FallibleChannel<T>
    var closure: (ChannelResult<T>) -> Void

    init(channel: FallibleChannel<T>, closure: (ChannelResult<T>) -> Void) {
        self.channel = channel
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.registerReceive(clause, index: index)
    }

    func execute() {
        if let result = channel.getResultFromBuffer() {
            closure(result)
        }
    }
}

final class FallibleReceivingChannelReceiveCase<T>: SelectCase {
    let channel: FallibleReceivingChannel<T>
    var closure: (ChannelResult<T>) -> Void

    init(channel: FallibleReceivingChannel<T>, closure: (ChannelResult<T>) -> Void) {
        self.channel = channel
        self.closure = closure
    }
    
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.registerReceive(clause, index: index)
    }
    
    func execute() {
        if let result = channel.getResultFromBuffer() {
            closure(result)
        }
    }
}

final class ChannelSendCase<T>: SelectCase {
    let channel: Channel<T>
    var value: T
    let closure: (Void) -> Void

    init(channel: Channel<T>, value: T, closure: (Void) -> Void) {
        self.channel = channel
        self.value = value
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(value, clause: clause, index: index)
    }

    func execute() {
        closure()
    }
}

final class SendingChannelSendCase<T>: SelectCase {
    let channel: SendingChannel<T>
    var value: T
    let closure: (Void) -> Void

    init(channel: SendingChannel<T>, value: T, closure: (Void) -> Void) {
        self.channel = channel
        self.value = value
        self.closure = closure
    }
    
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(value, clause: clause, index: index)
    }
    
    func execute() {
        closure()
    }
}

final class FallibleChannelSendCase<T>: SelectCase {
    let channel: FallibleChannel<T>
    let value: T
    let closure: (Void) -> Void

    init(channel: FallibleChannel<T>, value: T, closure: (Void) -> Void) {
        self.channel = channel
        self.value = value
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(value, clause: clause, index: index)
    }

    func execute() {
        closure()
    }
}

final class FallibleSendingChannelSendCase<T>: SelectCase {
    let channel: FallibleSendingChannel<T>
    let value: T
    let closure: (Void) -> Void

    init(channel: FallibleSendingChannel<T>, value: T, closure: (Void) -> Void) {
        self.channel = channel
        self.value = value
        self.closure = closure
    }
    
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(value, clause: clause, index: index)
    }
    
    func execute() {
        closure()
    }
}

final class FallibleChannelSendErrorCase<T>: SelectCase {
    let channel: FallibleChannel<T>
    let error: ErrorProtocol
    let closure: (Void) -> Void

    init(channel: FallibleChannel<T>, error: ErrorProtocol, closure: (Void) -> Void) {
        self.channel = channel
        self.error = error
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(error, clause: clause, index: index)
    }

    func execute() {
        closure()
    }
}

final class FallibleSendingChannelSendErrorCase<T>: SelectCase {
    let channel: FallibleSendingChannel<T>
    let error: ErrorProtocol
    let closure: (Void) -> Void

    init(channel: FallibleSendingChannel<T>, error: ErrorProtocol, closure: (Void) -> Void) {
        self.channel = channel
        self.error = error
        self.closure = closure
    }
    
    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.send(error, clause: clause, index: index)
    }
    
    func execute() {
        closure()
    }
}

final class TimeoutCase<T>: SelectCase {
    let channel: Channel<T>
    let closure: (Void) -> Void

    init(channel: Channel<T>, closure: (Void) -> Void) {
        self.channel = channel
        self.closure = closure
    }

    func register(_ clause: UnsafeMutablePointer<Void>, index: Int) {
        channel.registerReceive(clause, index: index)
    }

    func execute() {
        closure()
    }
}

public class SelectCaseBuilder {
    var cases: [SelectCase] = []
    var otherwise: ((Void) -> Void)?

    public func received<T>(valueFrom channel: Channel<T>?, closure: (T) -> Void) {
        if let channel = channel {
            let selectCase = ChannelReceiveCase(channel: channel, closure: closure)
            cases.append(selectCase)
        }
    }
    
    public func received<T>(valueFrom channel: ReceivingChannel<T>?, closure: (T) -> Void) {
        if let channel = channel {
            let selectCase = ReceivingChannelReceiveCase(channel: channel, closure: closure)
            cases.append(selectCase)
        }
    }

    public func received<T>(resultFrom channel: FallibleChannel<T>?, closure: (ChannelResult<T>) -> Void) {
        if let channel = channel {
            let selectCase = FallibleChannelReceiveCase(channel: channel, closure: closure)
            cases.append(selectCase)
        }
    }
    
    public func received<T>(resultFrom channel: FallibleReceivingChannel<T>?, closure: (ChannelResult<T>) -> Void) {
        if let channel = channel {
            let selectCase = FallibleReceivingChannelReceiveCase(channel: channel, closure: closure)
            cases.append(selectCase)
        }
    }

    public func sent<T>(_ value: T, to channel: Channel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = ChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(selectCase)
        }
    }
    
    public func sent<T>(_ value: T, to channel: SendingChannel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = SendingChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(selectCase)
        }
    }

    public func sent<T>(_ value: T, to channel: FallibleChannel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = FallibleChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(selectCase)
        }
    }
    
    public func sent<T>(_ value: T, to channel: FallibleSendingChannel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = FallibleSendingChannelSendCase(channel: channel, value: value, closure: closure)
            cases.append(selectCase)
        }
    }

    public func sent<T>(_ error: ErrorProtocol, to channel: FallibleChannel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = FallibleChannelSendErrorCase(channel: channel, error: error, closure: closure)
            cases.append(selectCase)
        }
    }
    
    public func sent<T>(_ error: ErrorProtocol, to channel: FallibleSendingChannel<T>?, closure: (Void) -> Void) {
        if let channel = channel where !channel.closed {
            let selectCase = FallibleSendingChannelSendErrorCase(channel: channel, error: error, closure: closure)
            cases.append(selectCase)
        }
    }

    public func timedOut(_ deadline: Double, closure: (Void) -> Void) {
        let done = Channel<Bool>()
        co {
            wake(at: deadline)
            done.send(true)
        }
        let selectCase = TimeoutCase<Bool>(channel: done, closure: closure)
        cases.append(selectCase)
    }

    public func otherwise(_ closure: (Void) -> Void) {
        self.otherwise = closure
    }
}

private func select(_ builder: SelectCaseBuilder) {
    mill_choose_init("select")

    var clauses: [UnsafeMutablePointer<Void>] = []

    for (index, selectCase) in builder.cases.enumerated() {
        let clause = malloc(mill_clauselen())!
        clauses.append(clause)
        selectCase.register(clause, index: index)
    }

    if builder.otherwise != nil {
        mill_choose_otherwise()
    }

    let index = mill_choose_wait()

    if index == -1 {
        builder.otherwise?()
    } else {
        builder.cases[Int(index)].execute()
    }
    
    clauses.forEach(free)
}

public func select(_ build: @noescape (when: SelectCaseBuilder) -> Void) {
    let builder = SelectCaseBuilder()
    build(when: builder)
    select(builder)
}

public func sel(_ build: @noescape (when: SelectCaseBuilder) -> Void) {
    select(build)
}

public func forSelect(_ build: @noescape (when: SelectCaseBuilder, done: (Void) -> Void) -> Void) {
    let builder = SelectCaseBuilder()
    var keepRunning = true
    func done() {
        keepRunning = false
    }
    while keepRunning {
        let builder = SelectCaseBuilder()
        build(when: builder, done: done)
        select(builder)
    }
}

public func forSel(build: @noescape (when: SelectCaseBuilder, done: (Void) -> Void) -> Void) {
    forSelect(build)
}
