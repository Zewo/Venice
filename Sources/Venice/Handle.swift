#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

public typealias HandleDescriptor = Int32

/// Representation of a Venice resource like `Coroutine` and `Channel`.
open class Handle {
    public var handle: HandleDescriptor
    
    public init(handle: HandleDescriptor) {
        self.handle = handle
    }

    /// Returns an opaque pointer associated with the passed type.
    /// This function is a fundamental construct for building APIs on top of handles.
    ///
    /// The `type` argument is used as a unique ID.
    /// An unique ID can be created like this:
    ///
    /// ```swift
    /// let type = TypeIdentifier.make()
    /// ```
    ///
    /// The return value has no specified semantics. It is an opaque pointer.
    ///
    /// Pointers returned by hquery are meant to be cachable.
    /// In other words, if you call hquery on the same handle with the same type multiple times,
    /// the result should be the same.
    ///
    /// - Parameter type: Unique ID for a protocol type.
    /// - Returns: An opaque pointer.
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidFileDescriptor
    ///   Thrown when the operation is performed on an invalid a handle.
    ///   #### VeniceError.operationNotSupported
    ///   Thrown when the provided type parameter doesn't match any of the 
    ///   types supported by the handle.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    func query<T>(_ type: TypeIdentifier) throws -> T {
        guard let result = hquery(handle, type.type) else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidHandle
            case ENOTSUP:
                throw VeniceError.operationNotSupported
            default:
                throw VeniceError.unexpectedError
            }
        }
        
        return result.assumingMemoryBound(to: T.self).pointee
    }
    
    /// Checks if the handle is open.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidHandle
    ///   Thrown when the operation is performed on an invalid a handle.
    func check() throws {
        errno = 0
        if hquery(handle, nil) == nil && errno == EBADF {
            throw VeniceError.invalidHandle
        }
    }
    
    /// This function is used to inform the handle that there will be no more input.
    /// This gives it time to finish it's work and possibly inform the user when it is
    /// safe to close the handle.
    ///
    /// For example, in case of TCP protocol handle, hdone sends out a FIN packet.
    /// However, it does not wait until it is acknowledged by the peer.
    ///
    /// - Warning:
    /// After `done` is called on a handle, any attempts to send more data to the handle
    /// will result in a `VeniceError.handleIsDone` error.
    /// - Warning:
    /// Handle implementation may also decide to prevent any further receiving of data
    /// and return `VeniceError.handleIsDone` error instead.
    ///
    /// - Parameters:
    ///   - deadline: `deadline` is a point in time when the operation should timeout.
    ///     Use the `.fromNow()` function to get the current point in time.
    ///     Use `.immediate` if the operation needs to be performed without blocking.
    ///     Use `.never` to allow the operation to block forever if needed.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidHandle
    ///   Thrown when the operation is performed on an invalid handle.
    ///   #### VeniceError.operationNotSupported
    ///   Thrown when the operation is not supported.
    ///   #### VeniceError.handleIsDone
    ///   Thrown when the operation is performed on an done handle.
    ///   #### VeniceError.deadlineReached
    ///   Thrown when the operation reaches the deadline.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    open func done(deadline: Deadline) throws {
        let result = hdone(handle, deadline.value)
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidHandle
            case ENOTSUP:
                throw VeniceError.operationNotSupported
            case EPIPE:
                throw VeniceError.handleIsDone
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
    
    /// Closes the handle.
    ///
    /// - Warning:
    /// `close` guarantees that all associated resources are deallocated.
    /// However, it does not guarantee that the handle's work will have been fully finished.
    /// For example, outbound network data may not be flushed.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.invalidHandle
    ///   Thrown when the operation is performed on a invalid handle.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    open func close() throws {
        let result = hclose(handle)
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidHandle
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
}










class Bar : CustomHandle, Bytestream {
    private let bytestreamTable = BytestreamTable()
    
    public override init() throws {
        try super.init()
        
        table.query = onQuery
        table.done = onDone
        table.close = onClose
        
        bytestreamTable.receive = onReceive
        bytestreamTable.send = onSend
    }
    
    public func frobnicate() throws {
        try check()
        print("bar frobnicate")
    }
    
    private func onQuery(type: TypeIdentifier) -> QueryContext? {
        print("bar query")
        
        switch type {
        case BytestreamTable.type:
            return bytestreamTable
        default:
            return nil
        }
    }
    
    private func onDone(deadline: Deadline) throws {
        print("bar done")
    }
    
    private func onClose() {
        print("bar close")
    }
    
    private func onReceive(buffers: [UnsafeMutableRawBufferPointer], deadline: Deadline) throws {
        print("bar read")
    }
    
    private func onSend(buffers: [UnsafeRawBufferPointer], deadline: Deadline) throws {
        print("bar write")
    }
}

class Foo : CustomHandle {
    private let bar: Bar
    
    public init(bar: Bar) throws {
        self.bar = bar
        
        try super.init()
        
        table.done = onDone
        table.close = onClose
    }
    
    public func detach() throws -> Bar {
        try check()
        try close()
        return bar
    }
    
    private func onDone(deadline: Deadline) throws {
        print("foo done")
    }
    
    private func onClose() {
        print("foo close")
    }
}

class CustomHandle : Handle {
    public let table: HandleTable
    
    public init() throws {
        table = try HandleTable()
        super.init(handle: table.handle)
    }
}

/// Representation of a Venice resource.
final class HandleTable : QueryContext {
    public var handle: HandleDescriptor
    fileprivate let table: UnsafeMutablePointer<hvfs>
    
    public var query: (TypeIdentifier) -> QueryContext? = { _ in
        return nil
    }
    
    public var done: (Deadline) throws -> Void = { _ in
        throw VeniceError.operationNotSupported
    }
    
    public var close: (Void) -> Void = {}
    
    public var pointer: UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(table)
    }
    
    public init() throws {
        table = UnsafeMutablePointer<hvfs>.allocate(capacity: 1)
        table.pointee.query = hvfs_query
        table.pointee.close = hvfs_close
        table.pointee.done = hvfs_done
        
        let result = hmake(table)
        
        guard result != -1 else {
            table.deallocate(capacity: 1)
            
            switch errno {
            case ECANCELED:
                throw VeniceError.canceled
            case EINVAL:
                throw VeniceError.unexpectedError
            case ENOMEM:
                throw VeniceError.outOfMemory
            default:
                throw VeniceError.unexpectedError
            }
        }
        
        handle = result
        table.pointee.context = Unmanaged.passUnretained(self).toOpaque()
    }
    
    deinit {
        table.deallocate(capacity: 1)
    }
}

protocol QueryContext {
    var pointer: UnsafeMutableRawPointer { get }
}

protocol Bytestream {
    var handle: HandleDescriptor  { get }
}

extension Bytestream {
    func read(_ buffer: UnsafeMutableRawBufferPointer, deadline: Deadline) throws {
        let result = brecv(handle, buffer.baseAddress, buffer.count, deadline.value)
        
        guard result != -1 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidHandle
            case ECANCELED:
                throw VeniceError.canceled
            case ECONNRESET:
                throw VeniceError.brokenConnection
            case EINVAL:
                throw VeniceError.invalidArguments
            case ENOMEM:
                throw VeniceError.outOfMemory
            case ENOTSUP:
                throw VeniceError.operationNotSupported
            case EPIPE:
                throw VeniceError.closedConnection
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
    
    func write(_ buffer: UnsafeRawBufferPointer, deadline: Deadline) throws{
        let result = bsend(handle, buffer.baseAddress, buffer.count, deadline.value)
        
        guard result != -1 else {
            switch errno {
            case EBADF:
                throw VeniceError.invalidHandle
            case ECANCELED:
                throw VeniceError.canceled
            case ECONNRESET:
                throw VeniceError.brokenConnection
            case EINVAL:
                throw VeniceError.invalidArguments
            case ENOMEM:
                throw VeniceError.outOfMemory
            case ENOTSUP:
                throw VeniceError.operationNotSupported
            case EPIPE:
                throw VeniceError.closedConnection
            case ETIMEDOUT:
                throw VeniceError.deadlineReached
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
}

final class BytestreamTable : QueryContext {
    public static var type: TypeIdentifier {
        return TypeIdentifier(bsock_type)
    }
    
    public var receive: ([UnsafeMutableRawBufferPointer], Deadline) throws -> Void = { _ in}
    public var send: ([UnsafeRawBufferPointer], Deadline) throws -> Void = { _ in }
    
    fileprivate var table: UnsafeMutablePointer<bsock_vfs>
    
    public var pointer: UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(table)
    }
    
    public init() {
        self.table = UnsafeMutablePointer<bsock_vfs>.allocate(capacity: 1)
        self.table.pointee.bsendl = bsendl
        self.table.pointee.brecvl = brecvl
        self.table.pointee.context = Unmanaged.passUnretained(self).toOpaque()
    }
    
    deinit {
        table.deallocate(capacity: 1)
    }
}

func brecvl(
    table: UnsafeMutablePointer<bsock_vfs>?,
    first: UnsafeMutablePointer<iolist>?,
    last: UnsafeMutablePointer<iolist>?,
    deadline: Int64
) -> Int {
    guard let table = table else {
        errno = ENOTSUP
        return -1
    }
    
    let context = Unmanaged<BytestreamTable>.fromOpaque(table.pointee.context).takeUnretainedValue()
    var buffers: [UnsafeMutableRawBufferPointer] = []
    var next = first
    
    while let element = next?.pointee {
        let buffer = UnsafeMutableRawBufferPointer(
            start: element.iol_base,
            count: element.iol_len
        )
        
        buffers.append(buffer)
        next = element.iol_next
    }
    
    do {
        try context.receive(buffers, Deadline(deadline))
        return 0
    } catch {
        return -1
    }
}

func bsendl(
    table: UnsafeMutablePointer<bsock_vfs>?,
    first: UnsafeMutablePointer<iolist>?,
    last: UnsafeMutablePointer<iolist>?,
    deadline: Int64
) -> Int32 {
    guard let table = table else {
        errno = ENOTSUP
        return -1
    }
    
    let context = Unmanaged<BytestreamTable>.fromOpaque(table.pointee.context).takeUnretainedValue()
    var buffers: [UnsafeRawBufferPointer] = []
    var next = first
    
    while let element = next?.pointee {
        let buffer = UnsafeRawBufferPointer(
            start: element.iol_base,
            count: element.iol_len
        )
        
        buffers.append(buffer)
        next = element.iol_next
    }
    
    do {
        try context.send(buffers, Deadline(deadline))
        return 0
    } catch {
        return -1
    }
}

fileprivate func hvfs_query(
    table: UnsafeMutablePointer<hvfs>?,
    type: UnsafeRawPointer?
) -> UnsafeMutableRawPointer? {
    guard let table = table, let type = type else {
        errno = ENOTSUP
        return nil
    }
    
    let context = Unmanaged<HandleTable>.fromOpaque(table.pointee.context).takeUnretainedValue()
    
    guard let result = context.query(TypeIdentifier(type)) else {
        errno = ENOTSUP
        return nil
    }
    
    return result.pointer
}

fileprivate func hvfs_done(table: UnsafeMutablePointer<hvfs>?, deadline: Int64) -> Int32 {
    guard let table = table else {
        errno = ENOTSUP
        return -1
    }
    
    let context = Unmanaged<HandleTable>.fromOpaque(table.pointee.context).takeUnretainedValue()
    
    do {
        try context.done(Deadline(deadline))
        return 0
    } catch {
        return -1
    }
}

fileprivate func hvfs_close(table: UnsafeMutablePointer<hvfs>?) {
    guard let table = table else {
        return
    }
    
    let context = Unmanaged<HandleTable>.fromOpaque(table.pointee.context).takeUnretainedValue()
    return context.close()
}

class TypeIdentifier {
    let type: UnsafeRawPointer
    let owned: Bool
    
    init(_ type: UnsafeRawPointer, owned: Bool = false) {
        self.type = type
        self.owned = owned
    }
    
    convenience init() {
        let type = UnsafeMutableRawPointer.allocate(bytes: 1, alignedTo: 1)
        self.init(UnsafeRawPointer(type), owned: true)
    }
    
    deinit {
        if owned {
            type.deallocate(bytes: 1, alignedTo: 1)
        }
    }
    
    public static func make() -> TypeIdentifier {
        return TypeIdentifier()
    }
}

extension TypeIdentifier : Equatable {
    static func == (lhs: TypeIdentifier, rhs: TypeIdentifier) -> Bool {
        return lhs.type == rhs.type
    }
}
