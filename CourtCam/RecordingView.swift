//
//  ContentView.swift
//  CourtCam
//
//  Created by bpang24 on 6/26/25.
//

import SwiftUI
import Vision

// MARK: – Which alert to show?
enum ActiveAlert: Identifiable {
    case matched, autoStopped
    var id: Int { hashValue }
}

struct ContentView: View {
    @State private var detectedRect: VNRectangleObservation?
    @State private var isRecording = false
    @State private var showStopAlert = false
    @State private var unmatchedCount = 0
    
    // Guide is 60% of screen width; allow ±15% tolerance
    private let guideFraction: CGFloat = 0.6
    private let tolerance: CGFloat   = 0.25
    private let maxConsecutiveMisses = 5
    
    private var isMatched: Bool {
        guard let rect = detectedRect else { return false }
        return matchesGuide(rect)
    }
    
    var body: some View {
        ZStack {
            CameraView(detectedRectangle: $detectedRect, isRecording: $isRecording)
                .edgesIgnoringSafeArea(.all)
            
            // Translucent guide square
            GeometryReader { geo in
                let w = geo.size.width * guideFraction
                Rectangle()
                    .stroke(
                        isMatched
                        ? Color.green.opacity(0.8)
                        : Color.white.opacity(0.5),
                        lineWidth: 2
                    )
                    .frame(width: w, height: w)
                    .position(x: geo.size.width/2, y: geo.size.height/2)
                    .animation(.easeInOut(duration: 0.2), value: isMatched)
            }
            
            VStack {
                Spacer()
                
                ZStack {
                    // The “Hint” label behind, only when locked
                    if !isMatched {
                        Text("Align the court\nto enable recording")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .offset(y: -80)
                            .transition(.opacity)
                    }
                    
                    Button {
                        isRecording.toggle()
                    } label: {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                            .font(.system(size: 80))
                    }
                    .foregroundColor(isMatched
                                     ? (isRecording ? .yellow : .red)
                                     : .gray)        // gray out when not allowed
                    .opacity(isMatched ? 1.0 : 0.3)  // fade when not allowed
                    .disabled(!isMatched)
                    .scaleEffect(isMatched ? 1.0 : 0.8)  // slightly smaller when locked
                    .animation(.easeInOut(duration: 0.2), value: isMatched)
                    .padding(.bottom, 40)
                }
            }
            // Auto-stop when we lose the match during recording
            .onChange(of: isMatched) { old, new in
                if old && !new && isRecording {
                    unmatchedCount += 1
                    if unmatchedCount >= maxConsecutiveMisses {
                        isRecording = false
                        showStopAlert = true
                        unmatchedCount = 0
                    } else if new {
                        unmatchedCount = 0
                    }
                }
            }
            .alert("Recording stopped", isPresented: $showStopAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Court is no longer aligned.")
            }
        }
    }
    private func matchesGuide(_ rect: VNRectangleObservation) -> Bool {
        let guide = CGRect(
            x: (1 - guideFraction) / 2,
            y: (1 - guideFraction) / 2,
            width: guideFraction,
            height: guideFraction
        )
        
        let box = rect.boundingBox
        
        // Compute intersection
        guard let intersection = guide.intersection(box).isNull ? nil : guide.intersection(box) else {
            return false
        }
        let intersectionArea = intersection.width * intersection.height
        
        // Compute union = areaA + areaB − intersection
        let areaA = guide.width * guide.height
        let areaB = box.width * box.height
        let unionArea = areaA + areaB - intersectionArea
        
        let iou = intersectionArea / unionArea
        
        // Match if IoU ≥ 0.5 (you can tweak this threshold)
        return iou >= 0.5
    }
}
