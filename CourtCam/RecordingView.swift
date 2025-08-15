//
//  ContentView.swift
//  CourtCam
//
//  Created by bpang24 on 6/26/25.
//

import SwiftUI
import Vision
import UIKit
import PhotosUI
import AVKit

enum ActiveAlert: Identifiable {
    case stopped
    var id: Int { hashValue }
}

struct RecordingView: View {
    @State private var isCourt = false
    @State private var isRecording = false
    @State private var showStopAlert = false
    @State private var unmatchedCount = 0
    @State private var matchedCount = 0
    @State private var autoRecord = true
    @State private var activeAlert: ActiveAlert?
    @State private var showStartToast = false
    @State private var showHintToast = true
    @State private var startWorkItem: DispatchWorkItem?
    @State private var stopWorkItem:  DispatchWorkItem?
    @State private var referenceCourtPoints: [CGPoint] = []
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var previewURL: URL? = nil

    private let missThresh = 10
    private let matchThresh = 5
    
    var body: some View {
        ZStack {
            cameraLayer
            overlayImage
            RecordingControls(
                isRecording: $isRecording,
                isCourt: $isCourt,
                autoRecord: $autoRecord,
                toggleRecording: toggleRecording
            )
            VStack {
                Spacer()
                HStack {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showHintToast = false }
            }
        }
       
        .onChange(of: autoRecord) { _, new in
            print(autoRecord)
            matchedCount = 0
            unmatchedCount = 0
        }
        
        .onChange(of: isCourt) { _, newMatched in
            guard autoRecord else {
                startWorkItem?.cancel()
                stopWorkItem?.cancel()
                return
            }
            if newMatched {
                stopWorkItem?.cancel()
            } else {
                startWorkItem?.cancel()
            }

            let item = DispatchWorkItem {
                if newMatched {
                    if isCourt && !isRecording {
                        toggleRecording()
                    }
                } else {
                    if !isCourt && isRecording {
                        toggleRecording()
                    }
                }
            }
            if newMatched {
                startWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
            } else {
                stopWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
            }
        }
        .alert(item: $activeAlert) { _ in
          Alert(
            title:   Text("Recording stopped"),
            message: Text("Video saved to camera roll"),
            dismissButton: .default(Text("OK")) {
              activeAlert = nil
            }
          )
        }
        .overlay(
              Group {
                if showHintToast {
                  Text("Align the court to enable recording")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .transition(.opacity)
                }
              }
              .frame(maxWidth: .infinity,
                     maxHeight: .infinity,
                     alignment: .top)
              .padding(.top, 80)
            )
        .animation(.easeInOut, value: showHintToast)
        .overlay(
          Group {
            if showStartToast {
              Text("Recording started")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .transition(.opacity)
            }
          }
          .frame(maxWidth: .infinity,
                 maxHeight: .infinity,
                 alignment: .top)
          .padding(.top, 80)
        )
        .animation(.easeInOut, value: showStartToast)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItem,
            matching: .videos
        )
        .onChange(of: selectedItem) { _, newItem in
            loadVideo(from: newItem)
        }
        .sheet(item: $previewURL) { url in
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
        }
    }
    
    private var cameraLayer: some View {
        CameraView(isCourt: $isCourt, isRecording: $isRecording)
            .edgesIgnoringSafeArea(.all)
    }
    
    private var overlayImage: some View {
        Image(isCourt ? "court_green" : "court_white")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaledToFit()
            .ignoresSafeArea()
    }
    
    //MARK: Functions
    
    private func loadVideo(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mp4")
                    try data.write(to: tmp, options: .atomic)
                    await MainActor.run {
                        previewURL = tmp
                    }
                }
            } catch {
                print("❌ Failed to load video from PhotosPicker:", error)
            }
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        showStartToast = isRecording
        if isRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showStartToast = false }
            }
        } else {
            activeAlert = .stopped
        }
    }
}

struct RecordingControls: View {
    @Binding var isRecording: Bool
    @Binding var isCourt: Bool
    @Binding var autoRecord: Bool
    var toggleRecording: () -> Void

    var body: some View {
        let iconName = isRecording ? "stop.circle.fill" : "record.circle.fill"
        let color: Color = {
            if autoRecord {
                if isCourt {
                    return isRecording ? .yellow : .red
                } else {
                    return .gray
                }
            } else {
                return isRecording ? .yellow : .red
            }
        }()

        let opacity: Double = (autoRecord && !isCourt) ? 0.3 : 1.0
        let scale: CGFloat = (autoRecord && !isCourt) ? 0.8 : 1.0

        return VStack {
            HStack {
                Toggle("Auto-Record", isOn: $autoRecord)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                Spacer()
            }
            .padding()

            Spacer()

            ZStack {
                Button(action: toggleRecording) {
                    Image(systemName: iconName)
                        .font(.system(size: 80))
                }
                .foregroundColor(color)
                .opacity(opacity)
                .disabled(autoRecord && !isCourt)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.2), value: isCourt)
                .padding(.bottom, 40)
            }
        }
    }
}
