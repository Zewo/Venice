#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

/// A channel is a synchronization primitive.
///
/// # Threads
///
/// You can use Venice in multi-threaded programs.
/// However, individual threads are strictly separated.
/// You may think of each thread as a separate process.
///
/// In particular, a coroutine created in a thread will
/// be executed in that same thread, and it will never
/// migrate to a different one.
///
/// In a similar manner, a handle, such as a channel or
/// a coroutine handle, created in one thread cannot be
/// used in a different thread.
///
/// ## Example:
///
/// ```swift
/// let channel = Channel<Int>()
///
/// let coroutine = try Coroutine {
///     try channel.send(42, deadline: 1.second.fromNow())
/// }
///
/// let theAnswer = try channel.receive(deadline: 1.second.fromNow())
/// try coroutine.close()
/// ```
public final class Channel<Type> : Handle {
    private enum ChannelResult<Type> {
        case value(Type)
        case error(Error)

        fileprivate func getValue() throws -> Type {
            switch self {
            case .value(let value):
                return value
            case .error(let error):
                throw error
            }
        }
    }
    
    private var buffer = List<ChannelResult<Type>>()

    /// Creates a channel
    ///
    /// - Warning:
    ///   A channel is a synchronization primitive, not a container.
    ///   It doesn't store any items.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceled
    ///   Thrown when the operation is performed within a canceled coroutine.
    ///   #### VeniceError.outOfMemory
    ///   Thrown when the system doesn't have enough memory to perform the operation.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    public init() throws {
        let result = chmake(0)

        guard result != -1 else {
            switch errno {
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case ENOMEM:
                throw VeniceError.outOfMemory
            default:
                throw VeniceError.unexpectedError
            }
        }

        super.init(handle: result)
    }

    deinit {
        try? cancel()
    }
    
    /// Reference to the channel which can only send.
    public lazy var sendOnly: SendOnly = SendOnly(self)
    
    /// Reference to the channel which can only receive.
    public lazy var receiveOnly: ReceiveOnly = ReceiveOnly(self)

    /// Sends a value to the channel.
    public func send(_ value: Type, deadline: Deadline) throws {
        try send(.value(value), deadline: deadline)
    }

    /// Sends an error to the channel.
    public func send(_ error: Error, deadline: Deadline) throws {
        try send(.error(error), deadline: deadline)
    }

    private func send(_ channelResult: ChannelResult<Type>, deadline: Deadline) throws {
        let node = buffer.append(channelResult)
        let result = chsend(handle, nil, 0, deadline.value)

        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.canceledChannel
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case EPIPE:
                throw VeniceError.channelIsDone
            case ETIMEDOUT:
                buffer.remove(node)
                throw VeniceError.timeout
            default:
                throw VeniceError.unexpectedError
            }
        }
    }

    /// Receives a value from channel.
    @discardableResult public func receive(deadline: Deadline) throws -> Type {
        let result = chrecv(handle, nil, 0, deadline.value)

        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.canceledChannel
            case ECANCELED:
                throw VeniceError.canceledCoroutine
            case EPIPE:
                throw VeniceError.channelIsDone
            case ETIMEDOUT:
                throw VeniceError.timeout
            default:
                throw VeniceError.unexpectedError
            }
        }

        return try buffer.removeFirst().getValue()
    }
    
    /// Mark the channel as done.
    ///
    /// - Warning:
    ///   When a channel is marked as done it cannot receive or send anymore.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledChannel
    ///   Thrown when the operation is performed on a canceled channel.
    ///   #### VeniceError.channelIsDone
    ///   Thrown when the operation is performed on an done channel.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    public func done() throws {
        let result = chdone(handle)
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.canceledChannel
            case EPIPE:
                throw VeniceError.channelIsDone
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
    
    /// Send-only reference to an existing channel.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let channel = Channel<Int>()
    ///
    /// func send(to channel: Channel<Int>.SendOnly) throws {
    ///     try channel.send(42, deadline: 1.second.fromNow())
    /// }
    ///
    /// try send(to: channel.sendOnly)
    /// ```
    public final class SendOnly : Handle {
        private let channel: Channel<Type>
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
            super.init(handle: channel.handle)
        }
        
        /// Sends a value to the channel.
        public func send(_ value: Type, deadline: Deadline) throws {
            try channel.send(value, deadline: deadline)
        }
        
        /// Sends an error to the channel.
        public func send(_ error: Error, deadline: Deadline) throws {
            try channel.send(error, deadline: deadline)
        }
        
        /// Mark the channel as done.
        /// When a channel is marked as done it cannot receive or send anymore.
        public func done() throws {
            try channel.done()
        }
    }
    
    /// Receive-only reference to an existing channel.
    ///
    /// ## Example:
    ///
    /// ```swift
    /// let channel = Channel<Int>()
    ///
    /// func receive(from channel: Channel<Int>.ReceiveOnly) throws {
    ///     let value = try channel.receive(deadline: 1.second.fromNow())
    /// }
    ///
    /// try receive(from: channel.receiveOnly)
    /// ```
    public final class ReceiveOnly : Handle {
        private let channel: Channel<Type>
        
        fileprivate init(_ channel: Channel<Type>) {
            self.channel = channel
            super.init(handle: channel.handle)
        }
        
        /// Receives a value from channel.
        @discardableResult public func receive(deadline: Deadline) throws -> Type {
            return try channel.receive(deadline: deadline)
        }
        
        /// Mark the channel as done.
        /// When a channel is marked as done it cannot receive or send anymore.
        public func done() throws {
            try channel.done()
        }
    }
}
