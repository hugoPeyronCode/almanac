//
//  SetCard.swift
//  almanac
//
//  Created by Hugo Peyron on 12/06/2025.
//


import SwiftUI

struct SetCard: Identifiable, Equatable {
  let id = UUID()
  let color: SetColor
  let shape: SetShape
  let shading: SetShading
  let count: SetCount
}

enum SetColor: String, CaseIterable, Codable {
  case red, green, purple
}

enum SetShape: String, CaseIterable, Codable {
  case hourglass, star, roundedSquare
}

enum SetShading: String, CaseIterable, Codable {
  case solid, striped, outline
}

enum SetCount: Int, CaseIterable, Codable {
  case one = 1, two = 2, three = 3
}
