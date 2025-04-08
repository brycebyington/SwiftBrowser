//
//  Browser.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 3/31/25.
//  A messy port of Web Browser Engineering's Python Browser
//

import CoreText
import Foundation
// swift package manager library for use of the OpenSSL C library
import OpenSSL

// same thing as below but uses the ssl object instead of the socket
func sslReadLine(from ssl: OpaquePointer) -> String? {
    var statusLine = ""
    var buffer = [UInt8](repeating: 0, count: 1)

    while true {
        let bytesRead = SSL_read(ssl, &buffer, 1)
        if bytesRead <= 0 {
            // eof or error occurred
            break
        }
        if let char = String(bytes: buffer, encoding: .utf8) {
            statusLine.append(char)
            if char == "\n" {  // stop at newline
                break
            }
        }
    }
    return statusLine.isEmpty ? nil : statusLine
}

// re-creating readline from Python
func readLine(from socket: Int32) -> String? {
    var statusLine = ""
    var buffer = [UInt8](repeating: 0, count: 1)

    while true {
        let bytesRead = read(socket, &buffer, 1)
        if bytesRead <= 0 {
            // eof or an error occurred
            break
        }
        if let char = String(bytes: buffer, encoding: .utf8) {
            statusLine.append(char)
            if char == "\n" {  // stop at newline
                break
            }
        }
    }

    return statusLine.isEmpty ? nil : statusLine
}

class BrowserURL {
    // url string
    var urlString: String

    // parsed components of URL
    var scheme: String
    var host: String
    var path: String
    var port: Int?

    init(urlString: String) {
        self.urlString = urlString

        /*
         guard is functionally similar to assert in Python,
         with the added benefit of being able to handle errors
         safely through the else block. guard can also assert
         multiple conditions in a single statement.
         */

        // parse url using URLComponents
        guard let urlComponents = URLComponents(string: urlString) else {
            fatalError("Invalid URL")
        }

        // get the scheme from urlString and ensure that it is supported
        guard let scheme = urlComponents.scheme,
            ["http", "https"].contains(scheme)
        else {
            fatalError("Unsupported scheme")
        }
        self.scheme = scheme

        // get the host, default to empty string
        self.host = urlComponents.host ?? ""

        // get the path, default to "/" if empty
        self.path = urlComponents.path.isEmpty ? "/" : urlComponents.path

        // get the port, default to 80 for now
        if urlComponents.port == nil {
            if self.scheme == "https" {
                self.port = 443
            } else {
                self.port = 80
            }
        } else {
            self.port = urlComponents.port
        }
    }

    // perform an http request
    func request() -> Layout? {
        var response = ""

        // create the socket
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        // verify the socket was created successfully by checking that the returned value is a non-negative integer
        guard sockfd >= 0 else {
            perror("Socket failed to initialize")
            return nil
        }

        /*
            part of POSIX sockets API, used to provide and return network address information.
            hints tell getaddrinfo exactly what kind of socket addresses we are looking for.
            returns a list of address structures that match the below criteria
         */
        var hints: addrinfo = addrinfo(
            ai_flags: 0,  // behavior modifier
            ai_family: AF_INET,  // address family
            ai_socktype: SOCK_STREAM,  // type of socket
            ai_protocol: IPPROTO_TCP,  // protocol
            ai_addrlen: 0,  // length of address structure that ai_addr points to
            ai_canonname: nil,  // (optional) pointer to null-terminated string containing canonical name of the host
            ai_addr: nil,  // pointer to a sockaddr structure containing the actual address
            ai_next: nil  // pointer to the next node in linked list (since getaddrinfo can return multiple results)
        )

        /*
            unsafe: does not enforce swift memory safety like pointer validity,
            appropriate memory access, and proper memory management.
            mutable: allows for modification of the memory it points to
         */
        var addrInfo: UnsafeMutablePointer<addrinfo>?
        let portString = String(self.port ?? 80)
        let status = getaddrinfo(self.host, portString, &hints, &addrInfo)
        if status != 0 {
            print("getaddrinfo error: \(String(cString: gai_strerror(status)))")
            close(sockfd)
            return nil
        }

        // attempt to connect to a returned address
        var connected = false
        var infoPtr = addrInfo

        /*
            loop through addrInfo and try to connect to each address in the linked list.
            if successful, break. if unsuccessful, advance the pointer to the next
            address in the linked list.

            infoPtr = optional pointer to addrinfo structure
            infoPtr! -> force-unwrap infoPtr to access its value using .pointee
         */
        while infoPtr != nil {
            if connect(
                sockfd, infoPtr!.pointee.ai_addr, infoPtr!.pointee.ai_addrlen)
                == 0
            {
                connected = true
                break
            }
            // assign ai_next member back to infoPtr
            infoPtr = infoPtr!.pointee.ai_next
        }
        // free the pointer
        freeaddrinfo(addrInfo)

        // handle connection failure
        if !connected {
            print("Failed to connect")
            close(sockfd)
            return nil
        }

        var useSSL = false
        // opaque pointers are used to represent C pointers to types that cannot be represented in Swift
        var ssl: OpaquePointer? = nil
        // the ssl context
        var sslCtx: OpaquePointer? = nil
        if self.scheme.lowercased() == "https" {
            useSSL = true
            // initialize OpenSSL
            SSL_library_init()
            SSL_load_error_strings()
            OpenSSL_add_all_algorithms()

            // initialize tls client method
            guard let method = TLS_client_method() else {
                print("Error: Could not create TLS client method")
                close(sockfd)
                return nil
            }

            // create the ssl context from the method
            sslCtx = SSL_CTX_new(method)
            if sslCtx == nil {
                print("Error: Could not create SSL context")
                close(sockfd)
                return nil
            }

            // create the ssl object from the context
            ssl = SSL_new(sslCtx)
            if ssl == nil {
                print("Error: Could not create SSL object")
                SSL_CTX_free(sslCtx)
                close(sockfd)
                return nil
            }

            // associate the socket file descriptor with the ssl object
            SSL_set_fd(ssl, sockfd)

            // initiate the ssl/tls handshake
            if SSL_connect(ssl) != 1 {
                let err = SSL_get_error(ssl, 1)
                print("SSL_connect failed with error code: \(err)")
                SSL_free(ssl)
                SSL_CTX_free(sslCtx)
                close(sockfd)
                return nil
            }

            print("SSL/TLS connection established")
        }

        // format GET request
        let request =
            "GET \(self.path) HTTP/1.1\r\nHost: \(self.host)\r\nConnection: close\r\nUser-Agent: bryce-swift-browser\r\n\r\n"

        /*
            withCSString -> temporarily provides a pointer to null-terminated UTF-8
            representation of the string
            null terminated string: string stored as an array containing the characters
            and terminated with a nul "NUL" character that has an internal value of 0
            ptr -> points to string representation of HTTP request
            strlen(ptr) -> calculates number of bytes in string excluding "NUL" to send
            0 -> no special options
        */
        if useSSL {
            request.withCString { ptr in
                SSL_write(ssl, ptr, Int32(strlen(ptr)))
            }
        } else {
            let sentBytes = request.withCString { ptr -> Int in
                return send(sockfd, ptr, strlen(ptr), 0)
            }
            if sentBytes < 0 {
                perror("Failed to send request")
                close(sockfd)
                return nil
            }
        }

        /*
            buffer -> create a fixed-size buffer and repeatedly read data
            from the socket into the buffer until there is no more data. buffer
            is an array of 4096 bytes and initialized with zeroes
            read(s, &buffer, buffer.count) -> read attempts to read up to
            4096 bytes from the socket into the buffer. &buffer is a pointer reference.

            bytesRead > 0 -> at least some bytes were successfully read
            bytesRead = 0 -> no more bytes to read, exit loop
            bytesRead < 0 -> error occurred, exit loop

            take part of buffer that was filled from index 0 to bytesRead and convert to string
            using UTF-8 encoding. append the string to the response body.
            continue to accumulate the response until bytesRead = 0.

         */
        var buffer = [UInt8](repeating: 0, count: 4096)

        // read the status line
        var statusLine: String?
        if useSSL, let ssl = ssl {
            statusLine = sslReadLine(from: ssl)
        } else {
            statusLine = readLine(from: sockfd)
        }
        guard let line = statusLine else {
            print("Failed to read status line")
            close(sockfd)
            return nil
        }

        //split status line into its parts
        let info = line.split(separator: " ", maxSplits: 2)

        // split out important information
        print("version:", info[0])
        print("status:", info[1])
        print("explanation:", info[2])

        /*
            headers: empty dictionary of key:string : value:string
            first, read the current line until EOF or newline
            trimmedLine: header with trimmed whitespace and newline characters
            if it's empty, break
            parts: split trimmedLine on ":" into its key-value pair
            then make sure parts got a key-value pair
            parts[0]: header, parts[0]: value
            trim whitespaces
            append headers with the lower-case header and value pair

         */
        var headers: [String: String] = [:]
        // it would probably be good to split this out into its own function
        if useSSL, let ssl = ssl {
            while let headerLine = sslReadLine(from: ssl) {
                let trimmedLine = headerLine.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { break }
                let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let headerName = parts[0].trimmingCharacters(
                        in: .whitespaces)
                    let headerValue = parts[1].trimmingCharacters(
                        in: .whitespaces)
                    headers[headerName.lowercased()] = headerValue
                }
            }
        } else {
            while let headerLine = readLine(from: sockfd) {
                let trimmedLine = headerLine.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { break }
                let parts = trimmedLine.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let headerName = parts[0].trimmingCharacters(
                        in: .whitespaces)
                    let headerValue = parts[1].trimmingCharacters(
                        in: .whitespaces)
                    headers[headerName.lowercased()] = headerValue
                }
            }
        }

        // for each key-value pair, make sure that data isn't sent unusually
        for (key, value) in headers {
            print(key, value)
            guard key.lowercased() != "transfer-encoding",
                key.lowercased() != "content-encoding"
            else {
                print("Encoding not supported")
                close(sockfd)
                return nil
            }
        }

        // if https, read using SSL_read instead of read
        if useSSL {
            while true {
                let bytesRead = SSL_read(ssl, &buffer, Int32(buffer.count))
                if bytesRead <= 0 { break }
                if let part = String(
                    bytes: buffer[0..<Int(bytesRead)], encoding: .utf8)
                {
                    response.append(part)
                }
            }
        } else {
            while true {
                let bytesRead = read(sockfd, &buffer, buffer.count)
                if bytesRead <= 0 { break }
                if let part = String(
                    bytes: buffer[0..<bytesRead], encoding: .utf8)
                {
                    response.append(part)
                }
            }
        }
        // if https, shutdown the active ssl/tls connection
        if useSSL {
            SSL_shutdown(ssl)
            // free allocated memory
            SSL_free(ssl)
            if let ctx = sslCtx {
                SSL_CTX_free(ctx)
            }
        }
        close(sockfd)

        let rootElement = HTMLParser(body: response).parse()
        // optionally print layout/tree results for debugging
        // printTree(node: rootElement)
        // print(Layout(tokens: rootElement).displayList)
        let layout = Layout(tokens: rootElement)
        /*
        for item in layout.displayList {
            print("x: \(item.x), y: \(item.y), word: \(item.word)")
        }*/
        return layout

    }
    func lex(input: String) -> String? {
        var body = ""
        var inTag = false
        for c in input {
            if c == "<" {
                inTag = true
            } else if c == ">" {
                inTag = false
            } else if !inTag {
                body += String(c)
            }
        }

        // fix special characters
        let specialCharacters = [
            ["&amp;": "&"],
            ["&lt;": "<"],
            ["&gt;": ">"],
            ["&copy;": "©"],
            ["&ndash;": "–"],
        ]

        // thanks xcode autocomplete!
        // this just iterates over the dictionary and replaces the references with their actual character
        for sc in specialCharacters {
            for (k, v) in sc {
                body = body.replacingOccurrences(of: k, with: v)
            }
        }

        // return body and trim whitespace and newlines for now
        return (body.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
