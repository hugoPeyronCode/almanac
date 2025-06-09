//
//  DayCompletionStatus.swift
//  almanac
//
//  Created by Hugo Peyron on 09/06/2025.
//


import SwiftUI
import SwiftData

enum DayCompletionStatus {
  case none
  case partiallyCompleted(Int, Int)
  case allCompleted
}