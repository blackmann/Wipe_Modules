//
//  DirectoryEntries.swift
//  Wiper
//
//  Created by De-Great Yartey on 03/06/2023.
//

import SwiftUI
import Charts
import CoreData

let blacklist = [".git", ".next"]

struct Find: Identifiable {
  var id: String
  var path: String
  var moduleSize: UInt64
  var projectType: String
  var projectSize: UInt64
  var lastModified: Date
}

struct Summary: Identifiable {
  var id: String
  var size: UInt64
  var label: String
}

enum FindStatus {
  case complete
  case finding
  case idle
}

struct DirectoryEntries: View {
  @Environment(\.managedObjectContext) private var viewContext
  
  var path: String
  
  @State var finds: [Find] = []
  @State var status: FindStatus = .idle
  @State var showConfirm: Bool = false
  
  var body: some View {
    let modulesSize = self.getModulesSize()
    
    List {
      HStack {
        if status == .finding {
          ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(0.5)
        }
        
        Label(path[String.Index(utf16Offset: 7, in: path)...], systemImage: "folder")
          .foregroundColor(.secondary)
      }
      
      if !finds.isEmpty {
        Chart() {
          ForEach(getSummary()) { sum in
            BarMark(x: .value("Size", sum.size))
              .foregroundStyle(by: .value("Part", sum.label))
          }
        }.chartPlotStyle { content in
          content.frame(height: 30)
        }
      }
      
      if !finds.isEmpty {
        if modulesSize > 0 {
          Label("\(formatSize(modulesSize)) of node_modules found", systemImage: "info.circle")
            .font(.title2)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        } else {
          Label("All clear", systemImage: "checkmark.circle")
            .font(.title2)
            .foregroundColor(.green)
            .padding(.top, 8)
        }
      }

      Section {
        ForEach(finds) { find in
          HStack {
            VStack(alignment: .leading) {
              Text(cleanPathName(find.path))
              Text(find.lastModified.timeAgo()).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(formatSize(find.moduleSize)) / ") +
            Text("\(formatSize(find.projectSize))").foregroundColor(.secondary)
          }.padding(.vertical, 4)
        }
      } header: {
        if !finds.isEmpty { Text("Projects") }
      }
    }
    .navigationTitle(shortenName(path))
    .toolbar {
      ToolbarItem {
        Button(action: {load()}) {
          Label("Refresh", systemImage: "arrow.clockwise")
        }.help("Refresh")
      }
      
      ToolbarItem {
        Button(action: {
          showConfirm = true
        }) {
          Label("Start cleaning", systemImage: "play")
        }.help("Start wiping")
      }
    }
    .confirmationDialog("Are you sure you want to wipe all node_modules? They will be moved to the Trash. Empty trash to wipe totally.", isPresented: $showConfirm, actions: {
      Button(action: { wipeModules() }) {
        Text("Wipe modules")
      }
    })
    .onAppear {
      load()
    }
  }
  
  private func getModulesSize() -> UInt64 {
    var modulesSize: UInt64 = 0
    
    for find in finds {
      modulesSize += find.moduleSize
    }
    
    return modulesSize
  }
  
  private func wipeModules() {
    status = .finding
    
    let fileManager = FileManager.default
    var bytes: UInt64 = 0
    
    for var find in self.finds {
      if let url = URL(string: find.path + "/node_modules") {
        bytes += find.moduleSize
        let _ = try? fileManager.trashItem(at: url, resultingItemURL: nil)
        
        find.moduleSize = 0
      }
    }
    
    let wipeHistory = WipeHistory(context: viewContext)
    wipeHistory.bytes = Int64(bytes)
    wipeHistory.path = self.path
    wipeHistory.date = Date()
    
    let _ = try? viewContext.save()
    
    load()
  }
  
  private func load() {
    Task {
      status = .finding
      
      let finder = Finder()
      await finder.getStats(path: path)
      self.finds = await finder.results
      
      status = .complete
    }
  }
  
  private func getSummary() -> [Summary]{
    var modulesSize: UInt64 = 0
    var projectSize: UInt64 = 0 // this is the non-node_modules size
    
    for find in self.finds {
      modulesSize += find.moduleSize
      projectSize += find.projectSize - find.moduleSize
    }
    
    return [
      Summary(id: "projects", size: projectSize, label: "Projects"),
      Summary(id: "node_modules", size: modulesSize, label: "node_modules"),
    ]
  }
  
  private func cleanPathName(_ path: String) -> String {
    let cleaned = String(path[String.Index(utf16Offset: self.path.count, in: path)...])
    if cleaned.isEmpty { return "." }
    
    return cleaned
  }
  
  private func shortenName(_ path: String) -> String {
    var parts = path.split(separator: "/")
    var res = ""
    
    if let last = parts.popLast() {
      res += last.decomposedStringWithCanonicalMapping
    }
    
    if let last = parts.popLast() {
      res = last + "/" + res
    }
    
    if res.count > 0 {
      return res
    }
    
    return path
  }
}

actor Finder {
  var results: [Find] = []
  func getStats(path: String) {
    guard let url = URL(string: path) else { return }
    guard let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir else {
      return
    }
    
    let fileManager = FileManager.default
    
    var isProject = false
    let projectSize: UInt64 = directorySize(url: url)
    var modulesSize: UInt64 = 0
    var lastModified: Date = Date()
    
    do {
      let files = try fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false))
      let sorted = files.sorted()
      for fileName in sorted {
        if blacklist.contains(where: { $0 == fileName}) {
          continue
        }
        // get node_modules -> stats
        // check package.json
        // ^ determines that it's a project folder (only package.json means
        // node_modules was previously cleared)
        
        if fileName == "node_modules" {
          if let nodeModulesUrl = URL(string: url.absoluteString + fileName) {
            modulesSize = directorySize(url: nodeModulesUrl)
          }
          
          if let attrs = try? fileManager.attributesOfItem(atPath: url.path(percentEncoded: false) + fileName) {
            lastModified = attrs[.modificationDate] as! Date
          }
          
          isProject = true
          continue
        }
        
        if fileName.hasSuffix("package.json") {
          isProject = true
          // read project metadata
          continue
        }
        
        getStats(path: path + fileName + "/")
      }
    } catch {
      debugPrint(error)
    }
    
    if !isProject {
      return
    }
    
    let find = Find(id: path,
                    path: path,
                    moduleSize: modulesSize,
                    projectType: "Node",
                    projectSize: projectSize,
                    lastModified: lastModified)
    
    results.append(find)
  }
}

func directorySize(url: URL) -> UInt64 {
  let contents: [URL]
  do {
    contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
  } catch {
    return 0
  }
  
  var size: UInt64 = 0
  
  for url in contents {
    let isDirectoryResourceValue: URLResourceValues
    do {
      isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
    } catch {
      continue
    }
    
    if isDirectoryResourceValue.isDirectory == true {
      size += directorySize(url: url)
    } else {
      let fileSizeResourceValue: URLResourceValues
      do {
        fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
      } catch {
        continue
      }
      
      size += UInt64(fileSizeResourceValue.fileSize ?? 0)
    }
  }
  return size
}
