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

    public mutating func next() -> T? {
        return (try? channel.send()) ?? nil
    }
}

public enum ChannelValue<T> {
    case Value(T)
    case Error(ErrorType)
    
    public func success(closure: T -> Void) {
        switch self {
        case .Value(let value): closure(value)
        default: break
        }
    }
    
    public func failure(closure: ErrorType -> Void) {
        switch self {
        case .Error(let error): closure(error)
        default: break
        }
    }
}

public final class FallibleChannel<T> : SequenceType, FallibleSendable, FallibleReceivable {
    let channel: chan
    public let bufferSize: Int
    private var valuesInBuffer: Int = 0
    public var closed: Bool = false
    private var lastValue: ChannelValue<T>?

    public convenience init() {
        self.init(bufferSize: 0)
    }

    public init(bufferSize: Int) {
        self.channel = go_make_channel(strideof(ChannelValue<T>), bufferSize)
        self.bufferSize = bufferSize
    }

    deinit {
        go_free_channel(channel)
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
        closed = true

        if var value = lastValue {
            go_close_channel(channel, &value, strideof(ChannelValue<T>))
        }
    }

    /// Receives a value.
    public func receive(value: T) {
        lastValue = ChannelValue.Value(value)
        go_send_to_channel(channel, &lastValue, strideof(ChannelValue<T>))
        
        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Receives an error.
    public func receiveError(error: ErrorType) {
        lastValue = ChannelValue.Error(error)
        go_send_to_channel(channel, &lastValue, strideof(ChannelValue<T>))

        if bufferSize <= 0 || valuesInBuffer < bufferSize {
            valuesInBuffer++
        }
    }

    /// Sends a value.
    public func send() throws -> T? {
        let pointer = go_receive_from_channel(channel, strideof(ChannelValue<T>))
        if let value = valueFromPointer(pointer) {
            switch value {
            case .Value(let value): return value
            case .Error(let error): throw error
            }
        } else {
            return nil
        }
    }
    
    func valueFromPointer(pointer: UnsafeMutablePointer<Void>) -> ChannelValue<T>? {
        if closed && valuesInBuffer <= 0 {
            return nil
        } else {
            valuesInBuffer--
            let value = UnsafeMutablePointer<ChannelValue<T>>(pointer).memory
            lastValue = value
            return value
        }
    }
}

func fanIn<T>(channels: FallibleChannel<T>...) -> FallibleSendingChannel<T> {
    let fanInChannel = FallibleChannel<T>()
    for channel in channels { go { for element in channel { fanInChannel <- element } } }
    return fanInChannel.sendingChannel
}