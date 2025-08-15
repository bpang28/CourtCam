//
//  AnalysisView.swift
//  CourtCam
//
//  Created by bpang24 on 6/27/25.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import UIKit

extension Data {
    /// Append a UTF-8 string to a Data buffer
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}

extension URL: Identifiable {
  /// Make URLs usable in SwiftUI ForEach/etc. by using their string as an ID
  public var id: String { absoluteString }

   /// Returns a new URL by appending the given query items to this URL.
   func appending(queryItems newItems: [URLQueryItem]) -> URL {
     guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
       return self
     }
     var allItems = comps.queryItems ?? []
     allItems.append(contentsOf: newItems)
     comps.queryItems = allItems
     
     return comps.url ?? self
   }
 }

struct AnalysisView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var resultKey: String?
    @State private var pickedURL: URL?
    @State private var fullScreenURL: URL?
    @State private var isAnalyzing = false
    @State private var showPlayer = false
    @State private var showFileImporter = false
    @State private var resultURL: URL?
    @State private var archiveName: String = ""
    @State private var archiveStrokes: String = ""
    @State private var estimatedDuration: Double? = nil
    @State private var elapsedTime: Double = 0
    @State private var progressTimer: Timer? = nil
    @State private var player: AVPlayer? = nil
    @State private var didSave = false
    @State private var showErrorAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Thumbnail / filename preview
                if let url = pickedURL {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.title2)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .layoutPriority(1)
                    }
                    .padding(.horizontal)
                }
                // MARK: – Video picker button
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Text("Select from Gallery")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .onChange(of: pickerItem) { _, newItem in
                    loadVideo(from: newItem)
                }
                .padding(.horizontal)
                
                // MARK: – Files picker
                Button(action: { showFileImporter = true }) {
                    Text("Select from Files")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.movie],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let src = urls.first {
                            // Copy into temp for stable access
                            let ext = src.pathExtension
                            let dst = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension(ext)
                            try? FileManager.default.removeItem(at: dst)
                            do {
                                _ = src.startAccessingSecurityScopedResource()
                                try FileManager.default.copyItem(at: src, to: dst)
                                src.stopAccessingSecurityScopedResource()
                                pickedURL = dst
                            } catch {
                                print("File copy failed:", error)
                            }
                        }
                    case .failure(let error):
                        print("Failed to import file:", error)
                    }
                }
                .padding(.horizontal)
                
                // MARK: – Remove button
                if pickedURL != nil {
                    Button(role: .destructive) {
                        pickedURL = nil
                        resultURL = nil
                        resultKey = nil
                        fullScreenURL = nil
                        isAnalyzing = false
                        showPlayer = false
                        showFileImporter = false
                        archiveName = ""
                        estimatedDuration = nil
                        elapsedTime = 0
                        progressTimer = nil
                        player = nil
                    } label: {
                        Text("New Video")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
            
            .padding(.top, 0) // 👈 pushes down from title
            .padding(.bottom, 16) // 👈 space before video player
            
            // MARK: - Video Player bundle
            ZStack{
                Color.clear
                    .frame(height: 400) // adjust to the max height you expect
                    .allowsHitTesting(false)
                
                if let url = resultURL {
                    VStack(spacing: 12){
                        TextField("Save Name", text: $archiveName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        ZStack(alignment: .topTrailing) {
                            if let player {
                                VideoPlayer(player: player)
                                    .frame(height: 300)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                                    .padding(.horizontal)
                            }
                            
                            // expand button in the top‑right
                            Button {
                                fullScreenURL = url
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            .padding(10)
                        }
                        Button(action: {
                            archiveVideo(url: url, name: archiveName, note: archiveStrokes)
                            didSave = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                didSave = false
                            }
                        }) {
                            HStack {
                                Image(systemName: didSave ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                                Text(didSave ? "Saved" : "Save")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(didSave ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(didSave ? Color.green : Color.blue, lineWidth: 2)
                            )
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                if resultURL == nil && isAnalyzing == true, let estimate = estimatedDuration {
                    VStack {
                        Text("Analyzing…")
                        ProgressView(value: min(elapsedTime / estimate, 1.0))
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal,20)
                            .padding(.bottom,8)
                    }
                    .transition(.opacity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
                    
            // MARK: – Analyze button
            Spacer()
            
            Button {
                Task { await analyze()}
            } label: {
                if isAnalyzing {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Text("Analyze")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(pickedURL == nil ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .disabled(pickedURL == nil)
            .padding(.horizontal)
        }
        .onChange(of: resultURL) { newURL in
            if newURL != nil {
                let fmt = DateFormatter()
                fmt.dateFormat = "MM/dd/yyyy HH:mm:ss" // or "yyyy-MM-dd HH:mm:ss"
                archiveName = fmt.string(from: Date())
            }
         }
        .onChange(of: fullScreenURL) { newURL in
            guard let url = newURL else { return }
            presentFullscreenPlayer(url: url)
            fullScreenURL = nil
        }
        .alert("Analysis failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Try again")
        }
        .navigationTitle("Analyze Video")
    }

    private func startCountdown() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
            if let estimate = estimatedDuration, elapsedTime >= estimate {
                progressTimer?.invalidate()
            }
        }
    }
    
    private func presentFullscreenPlayer(url: URL) {
        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController else {
            return
        }

        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: url)
        playerVC.modalPresentationStyle = .fullScreen

        rootVC.present(playerVC, animated: true) {
            playerVC.player?.play()
        }
    }

    
    private func archiveVideo(url: URL, name: String, note: String) {
        // Make sure we have a processed S3 key to record
        guard let key = resultKey else { return }

        let fm = FileManager.default
        // Documents directory for this app sandbox
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logURL = docs.appendingPathComponent("archive_log.txt")

        do {
            // Check existing content
            var existing = ""
            if fm.fileExists(atPath: logURL.path) {
                existing = try String(contentsOf: logURL, encoding: .utf8)
            }

            if existing.contains("\(name),\(key)") {
                print("ℹ️ Entry already exists, skipping save.")
                return
            }

            let cleanNotes = (note ?? "").replacingOccurrences(of: "\n", with: " ")
            
            let entry = "\(name)|\(key)|\(cleanNotes)\n"
            // Append or write
            if !fm.fileExists(atPath: logURL.path) {
                try entry.write(to: logURL, atomically: true, encoding: .utf8)
            } else if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(entry.data(using: .utf8)!)
                handle.closeFile()
            }

            print("✅ Saved new archive entry: \(entry)")
        } catch {
            print("❌ Failed to check or write log:", error)
        }
    }
    
    private func analyze() async {
        guard let fileURL = pickedURL else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        // 1) Build request
        let url = URL(string:
          "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/analyze3?thresh=0.3&sample_rate=1&batch_size=30"
        )!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        // 2) Multipart form‑data
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)",
                     forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimeType = "video/\(fileURL.pathExtension)"
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        guard let fileData = try? Data(contentsOf: fileURL) else { return }
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        // 3) Session with long timeout
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 300
        cfg.timeoutIntervalForResource = 600
        let session = URLSession(configuration: cfg)

        do {
            // 1) UPLOAD
            let uploadURL = URL(string: "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/upload")!
            var uploadReq = URLRequest(url: uploadURL)
            uploadReq.httpMethod = "POST"
            let boundary = "Boundary-\(UUID().uuidString)"
            uploadReq.setValue("multipart/form-data; boundary=\(boundary)",
                               forHTTPHeaderField: "Content-Type")

            var uploadBody = Data()
            let filename = fileURL.lastPathComponent
            let mimeType = "video/\(fileURL.pathExtension)"
            uploadBody.append("--\(boundary)\r\n")
            uploadBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
            uploadBody.append("Content-Type: \(mimeType)\r\n\r\n")
            uploadBody.append( try Data(contentsOf: fileURL) )
            uploadBody.append("\r\n--\(boundary)--\r\n")
            uploadReq.httpBody = uploadBody

            let (uplData, uplResp) = try await session.data(for: uploadReq)
            guard let uplHTTP = uplResp as? HTTPURLResponse, uplHTTP.statusCode == 200 else {
                print("❌ upload failed:", uplResp)
                await MainActor.run {
                    showErrorAlert = true
                    isAnalyzing = false
                }
                return
            }
            struct UploadResponse: Decodable { let s3_key: String
                let estimated_time: Double }
            let upl = try JSONDecoder().decode(UploadResponse.self, from: uplData)
            let s3Key = upl.s3_key
            let estTime = upl.estimated_time
            print(estTime)
            estimatedDuration = estTime
            elapsedTime = 0
            startCountdown()

            // 2) ANALYZE
            var analyzeComps = URLComponents(string:
              "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/analyze3"
            )!
            analyzeComps.queryItems = [
              .init(name: "key", value: s3Key),
              .init(name: "thresh", value: "0.3"),
              .init(name: "sample_rate", value: "1"),
              .init(name: "batch_size", value: "30")
            ]
            let (anData, anResp) = try await session.data(from: analyzeComps.url!)
            guard let anHTTP = anResp as? HTTPURLResponse, anHTTP.statusCode == 200 else {
                print("❌ analyze failed:", anResp)
                await MainActor.run {
                    showErrorAlert = true
                    isAnalyzing = false
                }
                return
            }
            struct AnalyzeResponse: Decodable {
              let video_path: String
              let heatmap_paths: [String]
              let heatmap_folder: String
              let processing_time_seconds: Double
              let stroke_counts: [String: [String: Int]]
            }
            let analysis = try JSONDecoder().decode(AnalyzeResponse.self, from: anData)
            let processedKey = analysis.video_path
            print(processedKey)
            
            let strokes = analysis.stroke_counts

            // 3) FETCH
            var fetchComps = URLComponents(string:
              "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/fetch"
            )!
            fetchComps.queryItems = [.init(name: "key", value: processedKey)]
            let (vidData, fResp) = try await session.data(from: fetchComps.url!)
            guard let fHTTP = fResp as? HTTPURLResponse, fHTTP.statusCode == 200 else {
                print("❌ fetch failed:", fResp)
                await MainActor.run {
                    showErrorAlert = true
                    isAnalyzing = false
                }
                return
            }

            // write out and show
            let outURL = FileManager.default.temporaryDirectory
                         .appendingPathComponent("processed_\(UUID()).mp4")
            try vidData.write(to: outURL, options: .atomic)
            resultURL = outURL
            player = AVPlayer(url: outURL)
            showPlayer = true
            resultKey = processedKey
            archiveStrokes = """
            Near – FH: \(strokes["near"]?["forehand"] ?? 0), BH: \(strokes["near"]?["backhand"] ?? 0)
            Far – FH: \(strokes["far"]?["forehand"] ?? 0), BH: \(strokes["far"]?["backhand"] ?? 0)
            """
            analysisNotification()
        } catch {
            print("❌ upload/analyze/fetch failed:", error)
            await MainActor.run {
                showErrorAlert = true
                isAnalyzing = false
            }
        }
    }
    
    private func analysisNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Analysis Complete"
        content.body = "The video has been successfully analyzed."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil) // Deliver immediately

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Notification scheduled.")
            }
        }
    }

    /// Loads the picked video as raw Data, writes it to a temp file, and publishes its URL.
    private func loadVideo(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            do {
                // Load the picked video into memory
                if let videoData = try await item.loadTransferable(type: Data.self) {
                    // Figure out a file extension (usually "mov" or "mp4")
                    let ext = UTType.movie.preferredFilenameExtension ?? "mov"
                    // Create a stable temp URL
                    let dst = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(ext)
                    // Overwrite if needed
                    try? FileManager.default.removeItem(at: dst)
                    // Write out the data
                    try videoData.write(to: dst, options: .atomic)
                    // Publish on main thread
                    await MainActor.run {
                        pickedURL = dst
                    }
                }
            } catch {
                print("Failed to load video:", error)
            }
        }
    }
}
