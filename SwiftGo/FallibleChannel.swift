// FallibleChannel.swift
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

public struct FallibleChannelGenerator<T> : GeneratorType {
    let channel: FallibleSendingChannel<T>

    public mutating func next() -> Result<T>? {
        return channel.sendResult()
    }
}

public enum Result<T> {
    case Value(T)
    case Error(ErrorType)
    
    public func success(@noescape closure: T -> Void) {
        switch self {
        case .Value(let value): closure(value)
        default: break
        }
    }
    
    public func failure(@noescape closure: ErrorType -> Void) {
        switch self {
        case .Error(let error): closure(error)
        default: break
        }
    }
}

public final class FallibleChannel<T> : SequenceType, FallibleSendable, FallibleReceivable {
    private let channel: chan
    public var closed: Bool = false
    private var buffer: [Result<T>] = []

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.channel = mill_chmake(bufferSize)
    }

    deinit {
        mill_chclose(channel)
    }

    /// Reference that can only send values.
    public lazy var sendingChannel: FallibleSendingChannel<T> = FallibleSendingChannel(self)

    /// Reference that can only receive values.
    public lazy var receivingChannel: FallibleReceivingChannel<T> = FallibleReceivingChannel(self)

    /// Creates a generator.
    public func generate() -> FallibleChannelGenerator<T> {
        return FallibleChannelGenerator(channel: sendingChannel)
    }

    /// Closes the channel. When a channel is closed it cannot receive values anymore.
    public func close() {
        if !closed {
            closed = true
            mill_chdone(channel)
        }
    }

    /// Receives a result.
    public func receiveResult(result: Result<T>) {
        if !closed {
            buffer.append(result)
            mill_chs(channel)
        }
    }

    /// Receives a value.
    public func receive(value: T) {
        if !closed {
            let result = Result<T>.Value(value)
            buffer.append(result)
            mill_chs(channel)
        }
    }

    /// Receives a value from select.
    func receive(value: T, clause: UnsafeMutablePointer<Void>, index: Int) {
        if !closed {
            let result = Result<T>.Value(value)
            buffer.append(result)
            mill_choose_out(clause, channel, Int32(index))
        }
    }

    /// Receives an error.
    public func receiveError(error: ErrorType) {
        if !closed {
            let result = Result<T>.Error(error)
            buffer.append(result)
            mill_chs(channel)
        }
    }

    /// Receives an error from select.
    func receive(error: ErrorType, clause: UnsafeMutablePointer<Void>, index: Int) {
        if !closed {
            let result = Result<T>.Error(error)
            buffer.append(result)
            mill_choose_out(clause, channel, Int32(index))
        }
    }

    /// Sends a value.
    public func send() throws -> T? {
        if closed && buffer.count <= 0 {
            return nil
        }
        mill_chr(channel)
        if let value = getResultFromBuffer() {
            switch value {
            case .Value(let v): return v
            case .Error(let e): throw e
            }
        } else {
            return nil
        }
    }

    /// Sends a result.
    public func sendResult() -> Result<T>? {
        if closed && buffer.count <= 0 {
            return nil
        }
        mill_chr(channel)
        return getResultFromBuffer()
    }

    func registerSend(clause: UnsafeMutablePointer<Void>, index: Int) {
        mill_choose_in(clause, channel, Int32(index))
    }

    func getResultFromBuffer() -> Result<T>? {
        if closed && buffer.count <= 0 {
            return nil
        }
        return buffer.removeFirst()
    }

}

extension FallibleChannel {

    public class func fanIn<T>(channels: FallibleChannel<T>...) -> FallibleSendingChannel<T> {
        let fanInChannel = FallibleChannel<T>()
        for channel in channels { go { for element in channel { fanInChannel <- element } } }
        return fanInChannel.sendingChannel
    }

}