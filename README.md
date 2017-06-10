<p align="center">
<img src="https://github.com/Zewo/Venice/blob/master/Images/header.png?raw=true" width="250" />
</p>

# Venice

[![Swift][swift-badge]][swift-url]
[![License][mit-badge]][mit-url]
[![Slack][slack-badge]][slack-url]
[![Travis][travis-badge]][travis-url]
[![Codecov][codecov-badge]][codecov-url]
[![Codebeat][codebeat-badge]][codebeat-url]
[![Documentation][docs-badge]][docs-url]

**Venice** provides [structured concurrency](http://libdill.org//structured-concurrency.html) and [CSP](https://en.wikipedia.org/wiki/Communicating_sequential_processes) for **Swift**.

## Features

- Coroutines
- Coroutine cancelation
- Coroutine groups
- Channels
- Receive-only channels
- Send-only channels
- File descriptor polling

**Venice** wraps a [fork](https://github.com/Zewo/libdill) of the C library [libdill](https://github.com/sustrik/libdill).

## Installation

Before using Venice you need to install our [libdill](https://github.com/Zewo/libdill) fork. Follow the instruction for your operating system.

### macOS

On **macOS** install **libdill** using [brew](https://brew.sh).

```sh
brew install zewo/tap/libdill
```

### Linux

On **Linux** we have to add our **apt** source first. You only need to run this command once in a lifetime. You don't need to run it again if you already have.

```sh
echo "deb [trusted=yes] http://apt.zewo.io ./" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
```

Now just install the **libdill** apt package.

```sh
sudo apt-get install libdill
```

### Add **Venice** to **Package.swift**

After that just add `Venice` as a dependency in your `Package.swift` file.

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Zewo/Venice.git", majorVersion: 0, minor: 19)
    ]
)
```

## Documentation

You can check the [Venice API reference](http://zewo.github.io/Venice/) for more in-depth documentation.

## Structured Concurrency

Structured concurrency means that lifetimes of concurrent functions are cleanly nested. If coroutine `foo` launches coroutine `bar`, then `bar` must finish before `foo` finishes.

This is not structured concurrency:

![not-structured-concurrency](http://libdill.org/index1.jpeg "Not Structured Concurrency")

This is structured concurrency:

![structured-concurrency](http://libdill.org/index2.jpeg "Structured Concurrency")

The goal of structured concurrency is to guarantee encapsulation. If the `main` function calls `foo`, which in turn launches `bar` in a concurrent fashion, `main` will be guaranteed that once `foo` has finished, there will be no leftover functions still running in the background.

What you end up with is a tree of coroutines rooted in the `main` function. This tree spreads out towards the smallest worker functions, and you may think of this as a generalization of the call stack — a call tree, if you will. In it, you can walk from any particular function towards the root until you reach the main function:

![call-tree](http://libdill.org/index3.jpeg "Call Tree")

Venice implements structured concurrency by allowing you to cancel a running coroutine.

```swift
let coroutine = try Coroutine {
    let resource = malloc(1000)
    
    defer {
        free(resource)
    }
    
    while true {
        try Coroutine.wakeUp(100.milliseconds.fromNow())
        print(".")
    }
}

try Coroutine.wakeUp(1.second.fromNow())
coroutine.cancel()
```

 When a coroutine is being canceled all coroutine-blocking calls will start to throw `VeniceError.canceledCoroutine`. On one hand, this forces the function to finish quickly (there's not much you can do without coroutine-blocking functions); on the other hand, it provides an opportunity for cleanup.

In the example above, when `coroutine.cancel` is called the call to `Coroutine.wakeUp` inside the coroutine will throw `VeniceError.canceledCoroutine` and then the `defer` statement will run, thus releasing the memory allocated for `resource`.

## Threads

You can use Venice in multi-threaded programs. However, individual threads are strictly separated. You may think of each thread as a separate process.

In particular, a coroutine created in a thread will be executed in that same thread, and it will never migrate to a different one.

In a similar manner, a handle, such as a channel or a coroutine handle, created in one thread cannot be used in a different thread.

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

[swift-badge]: https://img.shields.io/badge/Swift-3.1-orange.svg?style=flat
[swift-url]: https://swift.org

[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license

[slack-image]: http://s13.postimg.org/ybwy92ktf/Slack.png
[slack-badge]: https://zewo-slackin.herokuapp.com/badge.svg
[slack-url]: http://slack.zewo.io

[travis-badge]: https://travis-ci.org/Zewo/Venice.svg?branch=master
[travis-url]: https://travis-ci.org/Zewo/Venice

[codecov-badge]: https://codecov.io/gh/Zewo/Venice/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/Zewo/Venice

[codebeat-badge]: https://codebeat.co/badges/bd12fff5-d499-4636-83e6-d4edf89585c5
[codebeat-url]: https://codebeat.co/projects/github-com-zewo-venice

[docs-badge]: http://zewo.github.io/Venice/badge.svg
[docs-url]: http://zewo.github.io/Venice
