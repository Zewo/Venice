#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

public typealias HandleDescriptor = Int32

/// Representation of a Venice resource like `Coroutine` and `Channel`.
open class Handle {
    /// Raw handle representing the resource.
    public var handle: HandleDescriptor
    
    /// Initializes `Handle` with the raw handle.
    ///
    /// - Parameter handle: Raw handle representing the resource.
    public init(handle: HandleDescriptor) {
        self.handle = handle
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
