//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basic
import Foundation

/// A regex to detect Windows directory paths such as '/d:/...'.
/// It captures the drive letter used.
fileprivate let windowsPathRegex = try! NSRegularExpression(pattern: "\\/([a-zA-Z]):.*", options: [])

/// The home directory of the current user (same as returned by Foundation's `NSHomeDirectory` method).
public var homeDirectoryForCurrentUser: AbsolutePath {
  return AbsolutePath(NSHomeDirectory())
}

extension AbsolutePath {

  /// Inititializes an absolute path from a string, expanding a leading `~` to `homeDirectoryForCurrentUser` first.
  public init(expandingTilde path: String) {
    if path.first == "~" {
      self.init(homeDirectoryForCurrentUser, String(path.dropFirst(2)))
    } else {
      self.init(path)
    }
  }
  
  /// Initializes an absolute path from a string, expanding a leading Windows drive letter ('/d:/...') to the WSL equivalent ('/mnt/d/...')
  public init(validatingAndExpandingWSL path: String) {
    #if os(Linux)
      // Support the special case where a user runs an
      // editor on Windows with the language server through
      // Windows Subsystem for Linux (WSL).
      // In this case, the editor will attempt to pass paths such as
      // '/d:/...' to the language server which, however, expects
      // them to be formatted as '/mnt/d/...'.
      if let windowsPathMatch = windowsPathRegex.firstMatch(in: path, range: NSMakeRange(0, path.length)) {
        let driveLetter = path.character(at: 1)
        let newPrefix = "/mnt\(driveLetter)"
        self.init(validating: newPrefix + path.dropFirst(3))
      } else {
        self.init(validating: path)
      }
    #else
      self.init(validating: path)
    #endif
  }
}
