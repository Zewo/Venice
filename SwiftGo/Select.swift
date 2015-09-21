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
    func execute() -> Bool
    func hasHash(hash: Int) -> Bool
}

struct ReceiveCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: T -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func execute() -> Bool {
        let pointer = go_select_value(strideof(T))
        let valuePointer = UnsafeMutablePointer<T>(pointer)
        closure(valuePointer.memory)
        return true
    }

    func hasHash(hash: Int) -> Bool {
        return false
    }
}

final class FailableReceiveCase<T> : SelectCase {
    let channel: FailableChannel<T>
    var valueClosure: (T -> Void)?
    var errorClosure: (ErrorType -> Void)?

    init(channel: FailableChannel<T>, valueClosure: T -> Void) {
        self.channel = channel
        self.valueClosure = valueClosure
        self.errorClosure = nil
    }

    init(channel: FailableChannel<T>, errorClosure: ErrorType -> Void) {
        self.channel = channel
        self.valueClosure = nil
        self.errorClosure = errorClosure
    }

    func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_in(clause, channel.channel, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() -> Bool {
        let pointer = go_select_value(strideof(ChannelValue<T>))
        let resultPointer = UnsafeMutablePointer<ChannelValue<T>>(pointer)
        let result = resultPointer.memory

        switch result {
        case .Value(let value):
            if let valueClosure = valueClosure {
                valueClosure(value)
                return true
            } else {
                return false
            }
        case .Error(let error):
            if let errorClosure = errorClosure {
                errorClosure(error)
                return true
            } else {
                return false
            }
        }
    }

    func hasHash(hash: Int) -> Bool {
        return channel.hashValue == hash
    }
}

struct SendCase<T> : SelectCase {
    let channel: Channel<T>
    var value: T
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_out(clause, channel.channel, &value, strideof(T), Int32(index))
    }

    func execute() -> Bool {
        closure()
        return true
    }

    func hasHash(hash: Int) -> Bool {
        return false
    }
}

struct FailableSendCase<T> : SelectCase {
    let channel: FailableChannel<T>
    let value: T
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Value(self.value)
        go_select_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() -> Bool {
        closure()
        return true
    }

    func hasHash(hash: Int) -> Bool {
        return false
    }
}

struct FailableSendErrorCase<T> : SelectCase {
    let channel: FailableChannel<T>
    let error: ErrorType
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        var channelValue = ChannelValue<T>.Error(self.error)
        go_select_out(clause, channel.channel, &channelValue, strideof(ChannelValue<T>), Int32(index))
    }

    func execute() -> Bool {
        closure()
        return true
    }

    func hasHash(hash: Int) -> Bool {
        return false
    }
}

struct TimeoutCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func execute() -> Bool {
        closure()
        return true
    }

    func hasHash(hash: Int) -> Bool {
        return false
    }
}

public class SelectCaseBuilder {
    var cases: [SelectCase] = []
    var otherwise: (Void -> Void)?

    private func findCaseWithHash(hash: Int) -> SelectCase? {
        return cases.filter({ $0.hasHash(hash) }).first
    }

    public func receiveFrom<T>(channel: Channel<T>, closure: T -> Void) {
        let patternCase = ReceiveCase(channel: channel, closure: closure)
        cases.append(patternCase)
    }

    public func receiveFrom<T>(channel: FailableChannel<T>, closure: T -> Void) {
        if let failableCase = findCaseWithHash(channel.hashValue) as? FailableReceiveCase<T> {
            failableCase.valueClosure = closure
        } else {
            let patternCase = FailableReceiveCase(channel: channel, valueClosure: closure)
            cases.append(patternCase)
        }
    }

    public func catchErrorFrom<T>(channel: FailableChannel<T>, closure: ErrorType -> Void) {
        if let failableCase = findCaseWithHash(channel.hashValue) as? FailableReceiveCase<T> {
            failableCase.errorClosure = closure
        } else {
            let patternCase = FailableReceiveCase(channel: channel, errorClosure: closure)
            cases.append(patternCase)
        }
    }

    public func send<T>(value: T, to channel: Channel<T>, closure: Void -> Void) {
        let patternCase = SendCase(channel: channel, value: value, closure: closure)
        cases.append(patternCase)
    }

    public func send<T>(value: T, to channel: FailableChannel<T>, closure: Void -> Void) {
        let patternCase = FailableSendCase(channel: channel, value: value, closure: closure)
        cases.append(patternCase)
    }

    public func throwError<T>(error: ErrorType, into channel: FailableChannel<T>, closure: Void -> Void) {
        let patternCase = FailableSendErrorCase(channel: channel, error: error, closure: closure)
        cases.append(patternCase)
    }

    public func timeout(deadline: Int, closure: Void -> Void) {
        let done = Channel<Bool>()

        go {
            nap(deadline)
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
    var done = false

    while !done {

        go_select_init()

        var clausePointers: [UnsafeMutablePointer<Void>] = []

        for (index, var pattern) in builder.cases.enumerate() {
            let clausePointer = malloc(go_clause_length())
            clausePointers.append(clausePointer)
            pattern.register(clausePointer, index: index)
        }

        if builder.otherwise != nil {
            go_select_otherwise()
        }

        let index = go_select_wait()
        
        if index == -1 {
            builder.otherwise?()
            done = true
        } else {
            let pattern = builder.cases[Int(index)]
            done = pattern.execute()
        }
        
        for pointer in clausePointers {
            free(pointer)
        }
    }
}