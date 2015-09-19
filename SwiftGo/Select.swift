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
    func call()
}

struct ReceiveCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: T -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func call() {
        let pointer = go_select_value(strideof(T))
        let valuePointer = UnsafeMutablePointer<T>(pointer)
        closure(valuePointer.memory)
    }
}

struct SendCase<T> : SelectCase {
    let channel: Channel<T>
    var value: T
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_out(clause, channel.channel, &value, strideof(T), Int32(index))
    }

    func call() {
        closure()
    }
}

struct TimeoutCase<T> : SelectCase {
    let channel: Channel<T>
    let closure: Void -> Void

    mutating func register(clause: UnsafeMutablePointer<Void>, index: Int) {
        go_select_in(clause, channel.channel, strideof(T), Int32(index))
    }

    func call() {
        closure()
    }
}

public class SelectCaseBuilder {
    var cases: [SelectCase] = []
    var otherwise: (Void -> Void)?

    public func receiveFrom<T>(channel: Channel<T>, closure: T -> Void) {
        let patternCase = ReceiveCase(channel: channel, closure: closure)
        cases.append(patternCase)
    }

    public func sendValue<T>(value: T, to channel: Channel<T>, closure: Void -> Void) {
        let patternCase = SendCase(channel: channel, value: value, closure: closure)
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
    } else {
        let pattern = builder.cases[Int(index)]
        pattern.call()
    }
    
    for pointer in clausePointers {
        free(pointer)
    }
}