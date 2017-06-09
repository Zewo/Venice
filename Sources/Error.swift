/// Venice operation error
public enum VeniceError : Error, Equatable {
    /// Thrown when the operation is performed within a canceled coroutine.
    case canceledCoroutine
    /// Thrown when the operation is performed on an invalid file descriptor.
    case invalidFileDescriptor
    /// Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    case fileDescriptorBlockedInAnotherCoroutine
    /// Thrown when the operation reaches the deadline.
    case deadlineReached
    /// Thrown when the system doesn't have enough memory to perform the operation.
    case outOfMemory
    /// Thrown when the operation is performed on an done channel.
    case doneChannel
    /// Thrown when a read operation fails.
    case readFailed
    /// Thrown when a write operation fails.
    case writeFailed
    
    /// Thrown when an unexpected error occurs.
    /// This should never happen in the regular flow of an application.
    case unexpectedError

    /// :nodoc:
    public static func == (lhs: VeniceError, rhs: VeniceError) -> Bool {
        switch (lhs, rhs) {
        case (.canceledCoroutine, .canceledCoroutine):
            return true
        case (.invalidFileDescriptor, .invalidFileDescriptor):
            return true
        case (.fileDescriptorBlockedInAnotherCoroutine, .fileDescriptorBlockedInAnotherCoroutine):
            return true
        case (.deadlineReached, .deadlineReached):
            return true
        case (.outOfMemory, .outOfMemory):
            return true
        case (.doneChannel, .doneChannel):
            return true
        case (.unexpectedError, .unexpectedError):
            return true
        case (.readFailed, .readFailed):
            return true
        case (.writeFailed, .writeFailed):
            return true
        default:
            return false
        }
    }
}
