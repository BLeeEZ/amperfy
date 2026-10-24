//
//  Created by Dimitrios Chatzieleftheriou on 01/06/2020.
//  Copyright © 2020 Decimal. All rights reserved.
//

import Foundation

// MARK: - Parser

protocol Parser {
  associatedtype Input
  associatedtype Output

  func parse(input: Input) -> Output
}

extension Parser {
  func eraseToAnyParser() -> AnyParser<Input, Output> {
    AnyParser(self)
  }
}

// MARK: - AnyParser

struct AnyParser<Input, Output>: Parser {
  private let _parse: (Input) -> Output

  init<P: Parser>(_ parser: P) where P.Input == Input, P.Output == Output {
    self._parse = parser.parse(input:)
  }

  func parse(input: Input) -> Output {
    _parse(input)
  }
}
