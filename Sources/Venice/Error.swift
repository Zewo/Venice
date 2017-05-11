/// Venice operation error
public enum VeniceError : Error, Equatable {
    /// Thrown when the operation is performed within a canceled coroutine.
    case canceledCoroutine
    /// Thrown when the operation is performed on an invalid file descriptor.
    case canceledChannel
    /// Thrown when another coroutine is already blocked on `poll` with this file descriptor.
    case invalidFileDescriptor
    /// Thrown when the operation is performed on a canceled channel.
    case fileDescriptorBlockedInAnotherCoroutine
    /// Thrown when the operation times out.
    case timeout
    /// Thrown when the system doesn't have enough memory to perform the operation.
    case outOfMemory
    /// Thrown when the operation is performed on an done channel.
    case channelIsDone
    /// Thrown when an unexpected error occurs.
    /// This should never happen in the regular flow of an application.
    case unexpectedError

    /// :nodoc:
    public static func == (lhs: VeniceError, rhs: VeniceError) -> Bool {
        switch (lhs, rhs) {
        case (.canceledCoroutine, .canceledCoroutine):
            return true
        case (.canceledChannel, .canceledChannel):
            return true
        case (.invalidFileDescriptor, .invalidFileDescriptor):
            return true
        case (.fileDescriptorBlockedInAnotherCoroutine, .fileDescriptorBlockedInAnotherCoroutine):
            return true
        case (.timeout, .timeout):
            return true
        case (.outOfMemory, .outOfMemory):
            return true
        case (.channelIsDone, .channelIsDone):
            return true
        case (.unexpectedError, .unexpectedError):
            return true
        default:
            return false
        }
    }
}
