//
//  ArchiveView.swift
//  CourtCam
//
//  Created by bpang24 on 7/25/25.
//

import SwiftUI
import AVFoundation
import _AVKit_SwiftUI

struct ArchiveEntry: Identifiable {
    let id = UUID()
    var name: String
    let key: String
    var notes: String = ""
}

struct ArchiveView: View {
    @State private var entries: [ArchiveEntry] = []
    @State private var showingConfirmClear = false
    @State private var selectedEntry: ArchiveEntry? = nil

    var body: some View {
        NavigationView {
            VStack(spacing:0){
                List(entries) { entry in
                    ArchiveRowView(entry: entry)
                        .onTapGesture {
                            selectedEntry = entry
                        }
                }
                
                // MARK: – Clear button at bottom
                Button(role: .destructive) {
                    showingConfirmClear = true
                } label: {
                    Text("Clear Archive Log")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                .padding(.vertical, 10)
            }
            .onAppear {
                loadArchiveLog()
            }
            .alert("Clear Archive?", isPresented: $showingConfirmClear) {
                Button("Clear", role: .destructive) {
                    clearArchiveLog()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete all saved entries from the archive.")
            }
            .sheet(item: $selectedEntry) { entry in
                // Make a binding to the matching entry in `entries`
                if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                    ArchiveDetailView(entry: $entries[i]) {
                        saveArchiveLog()
                    }
                }
            }
        }.navigationTitle("Archive Log")
    }

    private func loadArchiveLog() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logURL = docs.appendingPathComponent("archive_log.txt")

        guard let contents = try? String(contentsOf: logURL) else {
            print("⚠️ No archive_log.txt found at:", logURL.path)
            return
        }
        
        entries = contents
        .split(separator: "\n")
        .compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { return nil }

            let name = String(parts[0])
            let key = String(parts[1])
            let notes = parts.count > 2 ? parts[2...].joined(separator: ",") : ""
            return ArchiveEntry(name: name, key: key, notes: notes)
        }
    }
    
    private func clearArchiveLog() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logURL = docs.appendingPathComponent("archive_log.txt")

        do {
            try "".write(to: logURL, atomically: true, encoding: .utf8)
            entries.removeAll()
            print("🧹 archive_log.txt cleared.")
        } catch {
            print("❌ Failed to clear archive_log.txt:", error)
        }
    }
    
    private func saveArchiveLog() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logURL = docs.appendingPathComponent("archive_log.txt")

        let text = entries.map { "\($0.name),\($0.key),\($0.notes.replacingOccurrences(of: "\n", with: " "))" }
                          .joined(separator: "\n")

        do {
            try text.write(to: logURL, atomically: true, encoding: .utf8)
            print("✅ Archive saved.")
        } catch {
            print("❌ Failed to save archive:", error)
        }
    }
}

struct ArchiveRowView: View {
    let entry: ArchiveEntry

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "video.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(.blue)

            Text(entry.name)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ArchiveDetailView: View {
    @Binding var entry: ArchiveEntry
    @State private var draftName: String
    @State private var draftNotes: String
    @State private var videoURL: URL?
    @State private var videoHeight: CGFloat = 300
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss

    var save: () -> Void

    init(entry: Binding<ArchiveEntry>, save: @escaping () -> Void) {
        _entry = entry
        _draftName = State(initialValue: entry.wrappedValue.name)
        _draftNotes = State(initialValue: entry.wrappedValue.notes)
        self.save = save
    }
    
    var body: some View {
        ScrollView{
            VStack(spacing: 16) {
                TextField("Title", text: $draftName)
                    .font(.title2)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                if let player = player {
                    ZStack(alignment: .topTrailing) {
                        VideoPlayer(player: player)
                            .frame(height: videoHeight)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                        
                        Button {
                            if let asset = player.currentItem?.asset as? AVURLAsset {
                                let url = asset.url
                                dismiss() // dismiss the .sheet first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    presentVideoPlayer(with: url)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding(10)
                    }
                } else {
                    ProgressView("Loading video…")
                        .onAppear {
                            if videoURL == nil {
                                fetchVideo(for: entry.key)
                            }
                        }
                }
                
                TextField("Notes", text: $draftNotes, axis: .vertical)
                    .lineLimit(4...)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    Button(action: {
                        entry = ArchiveEntry(name: entry.name, key: entry.key, notes: entry.notes)
                        dismiss()
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                        
                    Button(action: {
                        entry.name = draftName
                        entry.notes = draftNotes
                        save()
                        dismiss()
                    }) {
                        Text("Save")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .navigationTitle("Details")
            }.padding(.top)
        }
        .ignoresSafeArea(.keyboard)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
    }
    
    private func presentVideoPlayer(with url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow),
              let rootVC = window.rootViewController else { return }
        
        let playerVC = RotatingAVPlayerViewController()
        playerVC.player = AVPlayer(url: url)

        rootVC.present(playerVC, animated: true) {
            playerVC.player?.play()
        }
    }
    
    private func fetchVideo(for key: String) {
        guard let url = URL(string: "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/fetch?key=\(key)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try? data.write(to: tmp)
            let asset = AVAsset(url: tmp)

            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                let height = abs(size.height / size.width * UIScreen.main.bounds.width)

                DispatchQueue.main.async {
                    player = AVPlayer(url: tmp)
                    videoHeight = height
                }
            } else {
                DispatchQueue.main.async {
                    player = AVPlayer(url: tmp)
                    videoHeight = 300
                }
            }
        }.resume()
    }
}
