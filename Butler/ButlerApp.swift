//
//  ButlerApp.swift
//  Butler
//
//  Created by Scalzo, Giordano on 04/03/2025.
//

import SwiftUI

@main
struct ButlerApp: App {
    @State var currentNumber: String = "1"
       
       var body: some Scene {
           MenuBarExtra(currentNumber, systemImage: "\(currentNumber).circle") {
               Button("One") {
                   currentNumber = "1"
               }
               .keyboardShortcut("1")

               Button("Two") {
                   currentNumber = "2"
               }
               .keyboardShortcut("2")

               Button("Three") {
                   currentNumber = "3"
               }
               .keyboardShortcut("3")
               Divider()
               Button("Quit") {
                   NSApplication.shared.terminate(nil)
               }.keyboardShortcut("q")
           }
       }
}
