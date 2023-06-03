//
//  Date+Extensions.swift
//  SawSide
//
//  Created by De-Great Yartey on 19/12/2022.
//

import Foundation

public extension Date {
  
  func isNow() -> Bool {
    abs(self.timeIntervalSinceNow) < 10
  }
  
  func timeAgo() -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
    formatter.zeroFormattingBehavior = .dropAll
    formatter.maximumUnitCount = 1
    return String(format: formatter.string(from: self, to: Date()) ?? "", locale: .current)
  }
  
  var summary: String {
    let dateFormatter = DateFormatter()
    
    if self.isNow() {
      return "just now"
    }
    
    if Calendar.current.isDateInYesterday(self) {
      return "yesterday"
    }
    
    if Calendar.current.isDateInToday(self) {
      dateFormatter.dateFormat = "hh:mm a"
      return dateFormatter.string(from: self)
    }
    
    dateFormatter.dateStyle = .short
    
    return dateFormatter.string(from: self)
  }
  
  var human: String {
    let dateFormatter = DateFormatter()
    
    if isNow() {
      return "just now"
    }
    
    if Calendar.current.isDateInToday(self) {
      dateFormatter.dateFormat = "hh:mm a"
      return dateFormatter.string(from: self)
    }
    
    
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    
    return dateFormatter.string(from: self)
  }
}
