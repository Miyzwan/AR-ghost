//
//  HomeView.swift
//  AR2
//

import SwiftUI

struct HomeView: View {
    @Binding var isARActive: Bool
    
    // State untuk animasi floating dan denyut
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 1. Latar Belakang Gelap
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 2. Efek Bercak Darah (Background Layer)
            GeometryReader { geometry in
                // Bercak Kiri Atas
                Circle()
                    .fill(Color(red: 0.6, green: 0, blue: 0).opacity(0.6))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.1)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                
                // Tetesan Darah Kanan
                Capsule()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: 40, height: 180)
                    .blur(radius: 20)
                    .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.4)
                
                // Bercak Bawah
                Ellipse()
                    .fill(Color(red: 0.8, green: 0, blue: 0).opacity(0.7))
                    .frame(width: 250, height: 120)
                    .blur(radius: 50)
                    .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
            }
            
            // 3. Setan-Setan Lucu Melayang (Background Layer)
            GeometryReader { geometry in
                // Setan Kanan Atas
                Text("👻")
                    .font(.system(size: 45))
                    .foregroundColor(.white.opacity(0.2))
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.2)
                    .offset(y: isAnimating ? -20 : 20)
                    .animation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isAnimating)
                
                // Setan Kiri Tengah
                Text("👻")
                    .font(.system(size: 65))
                    .foregroundColor(.purple.opacity(0.3))
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.5)
                    .offset(x: isAnimating ? -15 : 15, y: isAnimating ? 30 : -30)
                    .animation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: isAnimating)
                
                // Setan Kanan Bawah
                Text("👻")
                    .font(.system(size: 35))
                    .foregroundColor(.white.opacity(0.15))
                    .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.7)
                    .offset(y: isAnimating ? 15 : -15)
                    .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
            }
            
            // 4. Konten Utama (Foreground Layer)
            VStack(spacing: 20) {
                Spacer()
                
                // Icon Hantu Utama
                Text("👻")
                    .font(.system(size: 130))
                    .foregroundColor(.white)
                    .shadow(color: .red, radius: 30, x: 0, y: 0)
                    .offset(y: isAnimating ? -10 : 10)
                    .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    .padding(.bottom, 10)
                
                Text("AR GHOST")
                    .font(.system(size: 52, weight: .black, design: .serif))
                    .tracking(10)
                    .foregroundColor(.white)
                    .shadow(color: .red, radius: 15, x: 0, y: 5)
                
                Text("Temukan hantu imut yang muncul dari belakang dan berdiam di atas kepalamu...")
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 5)
                
                Spacer()
                
                // Tombol Start Seram
                Button(action: {
                    isARActive = true
                }) {
                    Text("PANGGIL HANTU")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .tracking(3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0), Color.black]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.red, lineWidth: 2)
                        )
                        .cornerRadius(15)
                        .shadow(color: .red.opacity(0.8), radius: 20, x: 0, y: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true // Memulai semua animasi saat view muncul
        }
    }
}

#Preview {
    ContentView() // Gunakan ContentView untuk preview agar state bisa dikelola dengan baik
}
