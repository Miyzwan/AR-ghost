//
//  ContentView.swift
//  AR2
//
//  Created by Dimas Dwi Ismaunnizam on 26/03/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isARActive = false
    @State private var gateOpen = true
    @State private var gateScale: CGFloat = 1.0

    private var isARActiveBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.isARActive },
            set: { newValue in
                if newValue == true && !self.isARActive {
                    self.closeGateAndEnterAR()
                } else if newValue == false && self.isARActive {
                    self.closeGateAndReturn()
                }
            }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Tampilan Utama (Home / AR)
                if isARActive {
                    GhostARView(isARActive: isARActiveBinding)
                } else {
                    HomeView(isARActive: isARActiveBinding)
                }
                
                // Overlay Gerbang Besi Gotik
                HStack(spacing: 0) {
                    GateDoorView(isLeft: true)
                        .offset(x: gateOpen ? -proxy.size.width / 2 - 100 : 0)
                    
                    GateDoorView(isLeft: false)
                        .offset(x: gateOpen ? proxy.size.width / 2 + 100 : 0)
                }
                .scaleEffect(gateScale)
                .allowsHitTesting(false) // Tombol di belakangnya tetap bisa ditekan jika gate terbuka
            }
        }
    }
    
    // Fungsi Masuk Alam Gaib
    func closeGateAndEnterAR() {
        // 1. Gerbang Tertutup (BLAAM!)
        withAnimation(.easeIn(duration: 0.8)) {
            gateOpen = false
            gateScale = 1.05 // Sedikit efek benturan
        }
        
        // 2. Transisi Alam saat gelap total
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isARActive = true // Pindah ke halaman AR
            
            // 3. Gerbang Terbuka dengan gaya tersedot (Zoom)
            withAnimation(.timingCurve(0.3, 0.0, 0.1, 1.0, duration: 2.0)) {
                gateOpen = true
                gateScale = 1.4 // Membesar seolah masuk menembus gerbang
            }
            
            // Kembalikan scale secara tersembunyi
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                gateScale = 1.0
            }
        }
    }
    
    // Fungsi Kembali ke Dunia Nyata
    func closeGateAndReturn() {
        // 1. Gerbang Menutup Perlahan
        withAnimation(.easeInOut(duration: 1.0)) {
            gateOpen = false
            gateScale = 1.05
        }
        
        // 2. Transisi Alam
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            isARActive = false
            
            // 3. Gerbang Terbuka Kembali Normal
            withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.5)) {
                gateOpen = true
                gateScale = 1.0
            }
        }
    }
}

// Komponen Visual Gerbang Gotik Seram
struct GateDoorView: View {
    var isLeft: Bool
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background Besi Karatan
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(white: 0.08), Color.black]),
                    startPoint: isLeft ? .leading : .trailing,
                    endPoint: isLeft ? .trailing : .leading
                )
                
                // Jeruji Besi dengan Tombak Segitiga
                HStack(spacing: proxy.size.width / 8) {
                    ForEach(0..<6) { i in
                        VStack(spacing: -5) {
                            // Mata Tombak
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .frame(width: 14, height: 25)
                                .foregroundColor(Color(white: 0.2))
                                .shadow(color: .black, radius: 2, x: 0, y: 5)
                            
                            // Batang Jeruji
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.6), Color.black]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 8)
                                .shadow(color: .black, radius: 5, x: isLeft ? 3 : -3, y: 0)
                        }
                        // Pola kurva gotik
                        .padding(.top, CGFloat([80, 50, 25, 10, 0, -10][isLeft ? i : 5-i]))
                    }
                }
                .padding(.horizontal, 15)
                
                // Sabuk Gerbang Horizontal
                VStack {
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(white: 0.1), Color.black]), startPoint: .top, endPoint: .bottom))
                        .frame(height: 20)
                        .shadow(color: .black, radius: 5, x: 0, y: 5)
                        .padding(.top, proxy.size.height * 0.35)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(white: 0.1), Color.black]), startPoint: .top, endPoint: .bottom))
                        .frame(height: 30)
                        .shadow(color: .black, radius: 5, x: 0, y: -5)
                        .padding(.bottom, proxy.size.height * 0.25)
                }
                
                // Pilar Tepi Batu Kokoh
                HStack {
                    if isLeft {
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.black, Color(white: 0.15)]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: 50)
                            .shadow(color: .black, radius: 15, x: 15, y: 0)
                        Spacer()
                    } else {
                        Spacer()
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [Color.black, Color(white: 0.15)]), startPoint: .trailing, endPoint: .leading))
                            .frame(width: 50)
                            .shadow(color: .black, radius: 15, x: -15, y: 0)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}
