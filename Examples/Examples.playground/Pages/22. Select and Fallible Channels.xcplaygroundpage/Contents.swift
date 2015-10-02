import SwiftGo
import Darwin

struct Error : ErrorType, CustomStringConvertible { let description: String }

func flipCoin(result: FallibleChannel<String>) {
    if arc4random_uniform(2) == 0 {
        result <- "Success"
    } else {
        result <- Error(description: "Something went wrong")
    }
}

let results = FallibleChannel<String>()

go(flipCoin(results))

select { when in
    when.receiveFrom(results) { result in
        result.success { value in
            print(value)
        }
        result.failure { error in
            print(error)
        }
    }
}
