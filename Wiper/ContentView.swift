//
//  ContentView.swift
//  Wiper
//
//  Created by De-Great Yartey on 03/06/2023.
//

import SwiftUI
import CoreData

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \WatchDirectories.path, ascending: true)],
    animation: .default)
  private var items: FetchedResults<WatchDirectories>
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \WipeHistory.path, ascending: true)],
    animation: .default)
  private var history: FetchedResults<WipeHistory>
  
  var body: some View {
    NavigationView {
      List {
        Section {
          ForEach(items) { item in
            NavigationLink {
              DirectoryEntries(path: item.path!)
            } label: {
              Text(cleanName(item.path!))
            }
            .contextMenu {
              Button {
                removeItem(item)
              } label: {
                Text("Remove")
              }
            }
          }
        } header: {
          Text("Watch folders")
        }
        .collapsible(false)
      }
      .safeAreaInset(edge: .bottom) {
        Text("\(getTotalWiped()) wiped so far")
          .foregroundColor(.secondary)
          .padding()
      }
      .toolbar {
        ToolbarItem {
          Button(action: selectFolder) {
            Label("Add Item", systemImage: "plus")
          }
        }
      }
      Text("Select an item")
    }
  }
  
  private func getTotalWiped() -> String {
    var wiped: UInt64 = 0
    for instance in history {
      wiped += UInt64(instance.bytes)
    }
    
    return formatSize(wiped)
  }
  
  private func cleanName(_ name: String) -> String {
    let parts = name.split(separator: "/")
    if let last = parts.last {
      return last.decomposedStringWithCanonicalMapping
    }
    return name
  }
  
  private func selectFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    
    if panel.runModal() == .OK {
      for url in panel.urls {
        addItem(url.absoluteString)
      }
    }
  }
  
  private func addItem(_ path: String) {
    withAnimation {
      let newItem = WatchDirectories(context: viewContext)
      newItem.path = path
      
      do {
        try viewContext.save()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }
  
  private func removeItem(_ path: WatchDirectories) {
    withAnimation {
      viewContext.delete(path)
    }
  }
}

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
