import CLibdill

/// Representation of a time interval.
///
/// To create a `Duration` you should use any of the following `Int` extensions:
///
/// - millisecond
/// - milliseconds
/// - second
/// - seconds
/// - minute
/// - minutes
/// - hour
/// - hours
///
/// ## Example:
/// ```swift
/// let oneMillisecond = 1.millisecond
/// let twoMilliseconds = 2.milliseconds
/// let oneSecond = 1.second
/// let twoSeconds = 2.seconds
/// let oneMinute = 1.minute
/// let twoMinutes = 2.minutes
/// let oneHour = 1.hour
/// let twoHours = 2.hours
/// ```
public struct Duration {
    let value: Int64
    
    fileprivate init(_ duration: Int) {
        self.value = Int64(duration)
    }
    
    /// Creates a `Deadline` from the duration.
    public func fromNow() -> Deadline {
        return Deadline(value + CLibdill.now())
    }
}

extension Duration : Equatable {
    /// :nodoc:
    public static func == (lhs: Duration, rhs: Duration) -> Bool {
        return lhs.value == rhs.value
    }
}

/// Representation of a deadline.
///
/// To create a `Deadline` you can either use the static values `.immediately` and `.never`
/// or call `fromNow()` from a previously created `Duration`.
///
/// ## Example:
/// ```swift
/// let deadline = 30.seconds.fromNow()
/// ```
public struct Deadline {
    /// Raw value representing the deadline.
    public let value: Int64
    
    init(_ deadline: Int64) {
        self.value = deadline
    }

    /// Deadline representing now.
    public static func now() -> Deadline {
        return Deadline(CLibdill.now())
    }
    
    /// Special value to be used if the operation needs to be performed without blocking.
    public static var immediately: Deadline {
        return Deadline(0)
    }

    /// Special value to be used to allow the operation to block forever if needed.
    public static var never: Deadline {
        return Deadline(-1)
    }
}

extension Int {
    /// `Duration` represented in milliseconds.
    public var millisecond: Duration {
        return Duration(self)
    }
    
    /// `Duration` represented in milliseconds.
    public var milliseconds: Duration {
        return millisecond
    }

    /// `Duration` represented in seconds.
    public var second: Duration {
        return Duration(self * 1000)
    }

    /// `Duration` represented in seconds.
    public var seconds: Duration {
        return second
    }

    /// `Duration` represented in minutes.
    public var minute: Duration {
        return Duration(self * 1000 * 60)
    }

    /// `Duration` represented in minutes.
    public var minutes: Duration {
        return minute
    }

    /// `Duration` represented in hours.
    public var hour: Duration {
        return Duration(self * 1000 * 60 * 60)
    }

    /// `Duration` represented in hours.
    public var hours: Duration {
        return hour
    }
}
