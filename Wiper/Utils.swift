//
//  Utils.swift
//  Wipe Modules
//
//  Created by De-Great Yartey on 03/06/2023.
//

import Foundation


public func formatSize(_ size: UInt64) -> String {
  if size < 1000 {
    return "\(size)B"
  }
  
  if size < 1000000 {
    let rounded: Float64 = Float64(size)/1000
    return String(format: "%.2fKB", rounded)
  }
  
  if size < 1000000000 {
    let rounded: Float64 = Float64(size)/1000000
    return String(format: "%.2fMB", rounded)
  }
  
  let rounded: Float64 = Float64(size)/1000000000
  return String(format: "%.2fGB", rounded)
}
