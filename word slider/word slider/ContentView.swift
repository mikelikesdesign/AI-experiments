//
//  ContentView.swift
//  word slider
//
//  Created by Michael Lee on 9/15/24.
//

import SwiftUI

struct ContentView: View {
    @State private var sliderPosition: CGPoint = .zero
    @State private var text: String = "Hi. Status update?"
    @State private var fontSize: CGFloat = 40
    @State private var isKnobEnlarged: Bool = false
    @State private var trackpadRotation: (x: CGFloat, y: CGFloat) = (0, 0)

    // Remove these unused state variables
    // @State private var textOpacity: Double = 1
    // @State private var textScale: CGFloat = 1
    // @State private var previousText: String = "Hey, how is it going?"
    // @State private var isTransitioning: Bool = false

    let screenHeight = UIScreen.main.bounds.height
    let trackpadHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    let knobSize: CGFloat = 40
    let knobEnlargementFactor: CGFloat = 1.5
    let initialKnobInset: CGFloat = 8
    let gridLines = 10
    let maxRotation: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                // Text card
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "C0EAFF"))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Text(text)
                        .font(.system(size: fontSize, weight: .medium))
                        .minimumScaleFactor(0.5)
                        .padding()
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .id(text) // This forces SwiftUI to create a new Text view when the text changes
                }
                .frame(width: geometry.size.width - 32, height: geometry.size.width - 32)
                .padding(.horizontal, 16) // Add this line
                .onChange(of: text) {
                    adjustFontSize(for: CGSize(width: geometry.size.width - 64, height: geometry.size.width - 64))
                }
                .animation(.easeInOut(duration: 0.3), value: text) // Move animation here

                Spacer()

                // Track pad
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "121212"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "F1F1F1"), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 0)

                    // Grid lines
                    Path { path in
                        for i in 1..<gridLines {
                            let x = CGFloat(i) * geometry.size.width / CGFloat(gridLines)
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: trackpadHeight))

                            let y = CGFloat(i) * trackpadHeight / CGFloat(gridLines)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)

                    // Labels
                    VStack {
                        Text("Professional")
                            .padding(.top, 8)
                            .foregroundColor(.gray.opacity(0.8))
                        Spacer()
                        Text("Fun")
                            .padding(.bottom, 8)
                            .foregroundColor(.gray.opacity(0.8))
                    }

                    HStack {
                        Text("Concise")
                            .padding(.leading, 8)
                            .foregroundColor(.gray.opacity(0.8))
                        Spacer()
                        Text("Detailed")
                            .padding(.trailing, 8)
                            .foregroundColor(.gray.opacity(0.8))
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: isKnobEnlarged ? knobSize * knobEnlargementFactor : knobSize,
                               height: isKnobEnlarged ? knobSize * knobEnlargementFactor : knobSize)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        .position(sliderPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        updateSliderPosition(value, in: geometry.size)
                                        isKnobEnlarged = true
                                    }
                                    updateText()
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isKnobEnlarged = false
                                    }
                                }
                        )
                }
                .rotation3DEffect(
                    .degrees(trackpadRotation.x),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(trackpadRotation.y),
                    axis: (x: 0, y: 1, z: 0)
                )
                .frame(width: geometry.size.width - 32, height: trackpadHeight)
                .padding(.horizontal, 16) // Add this line
                .padding(.bottom, 24)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.white)
        .onAppear {
            sliderPosition = CGPoint(x: knobSize/2 + initialKnobInset, y: knobSize/2 + initialKnobInset)
            updateText()  // Add this line
            adjustFontSize(for: CGSize(width: UIScreen.main.bounds.width - 64, height: UIScreen.main.bounds.width - 64))
        }
    }

    private func updateSliderPosition(_ value: DragGesture.Value, in size: CGSize) {
        let newPosition = value.location
        sliderPosition = limitPositionToTrackpad(newPosition, in: size)

        let normalizedX = (sliderPosition.x / size.width) * 2 - 1
        let normalizedY = (sliderPosition.y / trackpadHeight) * 2 - 1
        trackpadRotation.y = normalizedX * maxRotation
        trackpadRotation.x = -normalizedY * maxRotation
    }

    private func limitPositionToTrackpad(_ position: CGPoint, in size: CGSize) -> CGPoint {
        return CGPoint(
            x: min(max(position.x, knobSize/2), size.width - knobSize/2),
            y: min(max(position.y, knobSize/2), trackpadHeight - knobSize/2)
        )
    }

    private func normalizedPosition(for size: CGSize) -> CGPoint {
        return CGPoint(
            x: sliderPosition.x / size.width,
            y: sliderPosition.y / trackpadHeight
        )
    }

    private func updateText() {
        let normalizedPosition = normalizedPosition(for: UIScreen.main.bounds.size)

        if normalizedPosition.x < 0.5 && normalizedPosition.y < 0.5 {
            text = "Hi, please share your update."
        } else if normalizedPosition.x >= 0.5 && normalizedPosition.y < 0.5 {
            text = "Hello, I hope this message finds you well. I wanted to inquire about your current status and any updates you might have regarding our ongoing projects or tasks. Could you please provide a brief overview of your progress and any notable developments, thanks."
        } else if normalizedPosition.x < 0.5 && normalizedPosition.y >= 0.5 {
            text = "Yo! What's the scoop!"
        } else {
            text = "Hey there! How are you? Excited to hear about all the cool stuff happening! Any exciting adventures or mind blowing discoveries you want to share? I'm all ears and ready for a fun filled update extravaganza! 🎉"
        }
    }

    private func adjustFontSize(for size: CGSize) {
        let shortMessageFontSize: CGFloat = 40 // Fixed size for short messages
        let longMessageFontSize: CGFloat = 38 // New fixed size for long messages

        if text.count <= 30 { // Threshold for short messages
            fontSize = shortMessageFontSize
        } else {
            fontSize = longMessageFontSize
        }
    }
}

struct RotatedText: View {
    let text: String
    let angle: Double

    var body: some View {
        Text(text)
            .rotationEffect(.degrees(angle))
            .fixedSize()
            .frame(width: 20)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
