/// Venice operation error
public enum VeniceError : Error, Equatable {
    /// Thrown when the operation is performed on a closed handle.
    case canceled
    /// Thrown when the operation is not supported.
    case operationNotSupported
    /// Thrown when the operation is performed on an invalid handle.
    case invalidHandle
    /// Thrown when the operation is performed on an invalid file descriptor.
    case invalidFileDescriptor
    /// Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    case fileDescriptorBlockedInAnotherCoroutine
    /// Thrown when the operation reaches the deadline.
    case deadlineReached
    /// Thrown when the system doesn't have enough memory to perform the operation.
    case outOfMemory
    /// Thrown when the operation is performed on an done handle.
    case handleIsDone
    /// Thrown when the operation is performed on a broken connection.
    case brokenConnection
    /// Thrown when the operation is performed on a closed connection.
    case closedConnection
    /// Thrown when the operation is performed with invalid arguments.
    case invalidArguments
    
    /// Thrown when an unexpected error occurs.
    /// This should never happen in the regular flow of an application.
    case unexpectedError

    /// :nodoc:
    public static func == (lhs: VeniceError, rhs: VeniceError) -> Bool {
        switch (lhs, rhs) {
        case (.canceled, .canceled):
            return true
        case (.operationNotSupported, .operationNotSupported):
            return true
        case (.invalidHandle, .invalidHandle):
            return true
        case (.invalidFileDescriptor, .invalidFileDescriptor):
            return true
        case (.fileDescriptorBlockedInAnotherCoroutine, .fileDescriptorBlockedInAnotherCoroutine):
            return true
        case (.deadlineReached, .deadlineReached):
            return true
        case (.outOfMemory, .outOfMemory):
            return true
        case (.handleIsDone, .handleIsDone):
            return true
        case (.closedConnection, .closedConnection):
            return true
        case (.brokenConnection, .brokenConnection):
            return true
        case (.invalidArguments, .invalidArguments):
            return true
        case (.unexpectedError, .unexpectedError):
            return true
        default:
            return false
        }
    }
}
