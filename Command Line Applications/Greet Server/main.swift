// GreetServer.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

enum ConnectionStatus {
    case Established
    case Succeded
    case Failed
}

func greetServer(port port: Int) {
    do {
        let statistics = Channel<ConnectionStatus>()
        co(dashboard(statistics: statistics.sendingChannel))

        let ip = try IP(port: port)
        let serverSocket = try TCPServerSocket(ip: ip)
        
        try serverSocket.acceptClients { clientSocket in
            dialogue(clientSocket: clientSocket, statistics: statistics.receivingChannel)
        }
    } catch {
        print("Couldn't accept client sockets")
        print(error)
    }
}

func dashboard(statistics statistics: SendingChannel<ConnectionStatus>) {
    var connections = 0, active = 0, failed = 0

    while true {
        let status = !<-statistics

        if status == .Established {
            ++connections
            ++active
        } else {
            --active
        }

        if status == .Failed {
            ++failed
        }

        print("Total number of connections: \(connections)")
        print("Active connections: \(active)")
        print("Failed connections: \(failed)\n")
    }
}

func dialogue(clientSocket clientSocket: TCPClientSocket, statistics: ReceivingChannel<ConnectionStatus>) {
    defer {
        clientSocket.close()
    }

    statistics <- .Established
    let deadline = now + 10 * second

    do {
        try clientSocket.sendString("What's your name?\r\n", deadline: deadline)
        try clientSocket.flush(deadline)

        let name = try clientSocket.receiveString(untilDelimiter: "\r", deadline: deadline)!

        try clientSocket.sendString("Hello, \(name)\r\n", deadline: deadline)
        try clientSocket.flush(deadline)

        statistics <- .Succeded
    } catch {
        print("Couldn't communicate with client socket")
        print(error)
        statistics <- .Failed
    }
}

greetServer(port: 5555)
