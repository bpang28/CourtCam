//
//  ContentView.swift
//  CourtCam
//
//  Created by bpang24 on 6/27/25.
//

import Foundation
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                NavigationLink(destination: AnalysisView()){
                    Text("Analyze Video")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())
                
                
                NavigationLink(destination:
                    OrientationLockedView(orientation: .portrait) {
                        RecordingView()
                    }
                ) {
                    Text("Record")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.green)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: ArchiveView()){
                    Text("Saved Videos")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.red)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }.buttonStyle(PlainButtonStyle())
                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle("CourtCam")
        }
    }
}
