#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibdill

typealias HandleDescriptor = Int32

/// Representation of a Venice resource.
public class Handle {
    let handle: HandleDescriptor

    init(handle: HandleDescriptor) {
        self.handle = handle
    }
    
    /// Cancels the handle.
    ///
    /// - Warning:
    /// `cancel` guarantees that all associated resources are deallocated.
    /// However, it does not guarantee that the handle's work will have been fully finished.
    /// For example, outbound network data may not be flushed.
    ///
    /// - Throws: The following errors might be thrown:
    ///   #### VeniceError.canceledChannel
    ///   Thrown when the operation is performed on a canceled channel.
    ///   #### VeniceError.unexpectedError
    ///   Thrown when an unexpected error occurs.
    ///   This should never happen in the regular flow of an application.
    public func cancel() throws {
        let result = hclose(handle)
        
        guard result == 0 else {
            switch errno {
            case EBADF:
                throw VeniceError.canceledChannel
            default:
                throw VeniceError.unexpectedError
            }
        }
    }
}
