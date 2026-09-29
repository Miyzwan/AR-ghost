//
//  GhostARView.swift
//  AR2
//

import SwiftUI
import RealityKit
import ARKit
import Vision
import Combine

struct GhostARView: View {
    @Binding var isARActive: Bool
    
    // Animasi darah berdenyut dan menetes
    @State private var isPulsing = false
    
    // State untuk menampilkan info hantu jika diklik
    @State private var showGhostInfo = false
    
    // State untuk debug posisi tangan di layar
    @State private var handPosition: CGPoint?
    
    // State untuk gestur clap (transformasi)
    @State private var showClapIndicator = false
    @State private var clapProgress: CGFloat = 0.0

    var body: some View {
        ZStack {
            // Kamera AR dan 3D Objek
            ARViewContainer(showGhostInfo: $showGhostInfo, handPosition: $handPosition, showClapIndicator: $showClapIndicator, clapProgress: $clapProgress)
                .edgesIgnoringSafeArea(.all)
            
            // --- EFEK DARAH PINGGIR LAYAR (VIGNETTE RADIAL) ---
            GeometryReader { proxy in
                Rectangle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.clear, Color.clear, Color(red: 0.6, green: 0, blue: 0).opacity(1.0)]),
                            center: .center,
                            startRadius: proxy.size.width * 0.3,
                            endRadius: proxy.size.height * 0.7
                        )
                    )
                    .edgesIgnoringSafeArea(.all)
                    .opacity(isPulsing ? 1.0 : 0.4)
                    .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
            }
            .allowsHitTesting(false)
            
            // --- VIGNETTE MERAH KIRI ---
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0).opacity(0.9), Color(red: 0.4, green: 0, blue: 0).opacity(0.3), Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isPulsing)
                Spacer()
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            // --- VIGNETTE MERAH KANAN ---
            HStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0).opacity(0.9), Color(red: 0.4, green: 0, blue: 0).opacity(0.3), Color.clear]),
                            startPoint: .trailing,
                            endPoint: .leading
                        )
                    )
                    .frame(width: 80)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.3), value: isPulsing)
                
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            // --- VIGNETTE MERAH ATAS ---
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0).opacity(0.8), Color(red: 0.3, green: 0, blue: 0).opacity(0.2), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 70)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.5), value: isPulsing)
                Spacer()
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            // --- VIGNETTE MERAH BAWAH ---
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0).opacity(0.8), Color(red: 0.3, green: 0, blue: 0).opacity(0.2), Color.clear]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: 70)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.7), value: isPulsing)
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            // --- EFEK DARAH KELILING LAYAR (4 SISI) ---
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                // ===== ATAS =====
                HStack(alignment: .top, spacing: w / 7) {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), Color.clear]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 10, height: isPulsing ? 150 : 80)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0, blue: 0), Color.clear]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 15, height: isPulsing ? 90 : 180)
                        .animation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.7, green: 0, blue: 0), Color.clear]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: isPulsing ? 120 : 60)
                        .animation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.3, green: 0, blue: 0), Color.clear]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: isPulsing ? 200 : 130)
                        .animation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(1.0), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.55, green: 0, blue: 0), Color.clear]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 12, height: isPulsing ? 100 : 50)
                        .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.7), value: isPulsing)
                }
                .position(x: w / 2, y: 0)
                
                // ===== BAWAH =====
                HStack(alignment: .bottom, spacing: w / 6) {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), Color.clear]), startPoint: .bottom, endPoint: .top))
                        .frame(width: 12, height: isPulsing ? 120 : 70)
                        .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0, blue: 0), Color.clear]), startPoint: .bottom, endPoint: .top))
                        .frame(width: 18, height: isPulsing ? 80 : 140)
                        .animation(Animation.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.8), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0), Color.clear]), startPoint: .bottom, endPoint: .top))
                        .frame(width: 10, height: isPulsing ? 100 : 55)
                        .animation(Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.1), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.35, green: 0, blue: 0), Color.clear]), startPoint: .bottom, endPoint: .top))
                        .frame(width: 25, height: isPulsing ? 160 : 100)
                        .animation(Animation.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(1.2), value: isPulsing)
                }
                .position(x: w / 2, y: h)
                
                // ===== KIRI =====
                VStack(alignment: .leading, spacing: h / 7) {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), Color.clear]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: isPulsing ? 130 : 70, height: 10)
                        .animation(Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.4), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0), Color.clear]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: isPulsing ? 80 : 140, height: 14)
                        .animation(Animation.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.9), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0, blue: 0), Color.clear]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: isPulsing ? 110 : 50, height: 8)
                        .animation(Animation.easeInOut(duration: 1.9).repeatForever(autoreverses: true).delay(0.6), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.55, green: 0, blue: 0), Color.clear]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: isPulsing ? 170 : 90, height: 20)
                        .animation(Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(1.1), value: isPulsing)
                }
                .position(x: 0, y: h / 2)
                
                // ===== KANAN =====
                VStack(alignment: .trailing, spacing: h / 7) {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.45, green: 0, blue: 0), Color.clear]), startPoint: .trailing, endPoint: .leading))
                        .frame(width: isPulsing ? 100 : 55, height: 12)
                        .animation(Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(0.5), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.6, green: 0, blue: 0), Color.clear]), startPoint: .trailing, endPoint: .leading))
                        .frame(width: isPulsing ? 150 : 80, height: 16)
                        .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.2), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.35, green: 0, blue: 0), Color.clear]), startPoint: .trailing, endPoint: .leading))
                        .frame(width: isPulsing ? 90 : 160, height: 10)
                        .animation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(1.0), value: isPulsing)
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), Color.clear]), startPoint: .trailing, endPoint: .leading))
                        .frame(width: isPulsing ? 120 : 65, height: 22)
                        .animation(Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.8), value: isPulsing)
                }
                .position(x: w, y: h / 2)
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            // --- INFO HANTU OVERLAY ---
            if showGhostInfo {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mister Q (Si Hantu Imut)")
                            .font(.system(.title2, design: .serif))
                            .fontWeight(.black)
                            .tracking(2)
                            .foregroundColor(Color(red: 1.0, green: 0.2, blue: 0.2))
                        
                        Text("Jangan tertipu dengan bentuk lucunya! Dia senang menetap di atas kepala manusia dan perlahan-lahan menyedot aura kesedihanmu. Kalau kepalamu tiba-tiba terasa berat, mungkin dia pelakunya...")
                            .font(.system(.body, design: .serif))
                            .foregroundColor(.white)
                            .italic()
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.red, lineWidth: 2)
                    )
                    .shadow(color: .red, radius: 20, x: 0, y: 0)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 220) // Tampilkan di atas tombol-tombol
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: showGhostInfo)
                }
            }
            
            // --- DEBUG TRACKING KOTAK MERAH TANDA TANGAN ---
            if let pos = handPosition {
                Circle()
                    .stroke(Color.green, lineWidth: 4)
                    .background(Circle().fill(Color.green.opacity(0.3)))
                    .frame(width: 80, height: 80)
                    // pos.x sudah sesuai kiri-kanan layar, pos.y dari Vision adalah bawah-atas, layar adalah atas-bawah
                    .position(
                        x: pos.x * UIScreen.main.bounds.width,
                        y: (1.0 - pos.y) * UIScreen.main.bounds.height
                    )
                    .animation(.linear(duration: 0.1), value: pos)
            }
            
            // --- UI INDIKATOR CLAP (MENYATUKAN TANGAN) ---
            if showClapIndicator {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0.0, to: clapProgress)
                        .stroke(Color(red: 0.8, green: 0.0, blue: 0.0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear(duration: 0.1), value: clapProgress)
                        .shadow(color: Color(red: 0.8, green: 0.0, blue: 0.0), radius: 10)
                    
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.continuous))
                        .shadow(color: Color(red: 0.8, green: 0.0, blue: 0.0), radius: 10)
                        .scaleEffect(1.0 + clapProgress * 0.2)
                        .animation(.easeInOut(duration: 0.2), value: clapProgress)
                }
                .transition(.scale.combined(with: .opacity))
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            }
            
            // --- TOMBOL KEMBALI + INFO ---
            VStack {
                Spacer()
                
                Button(action: {
                    isARActive = false
                }) {
                    Text("KEMBALI KE ALAM NYATA")
                        .font(.system(size: 18, weight: .bold, design: .serif))
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
                
                // --- TOMBOL "?" INFO HANTU ---
                Button(action: {
                    withAnimation {
                        showGhostInfo.toggle()
                    }
                }) {
                    Text("?")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.white)
                        .frame(width: 55, height: 55)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(red: 0.5, green: 0, blue: 0), Color.black]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                        )
                        .shadow(color: .red.opacity(0.8), radius: 15, x: 0, y: 3)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    @Binding var showGhostInfo: Bool
    @Binding var handPosition: CGPoint?
    @Binding var showClapIndicator: Bool
    @Binding var clapProgress: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(showGhostInfo: $showGhostInfo, handPosition: $handPosition, showClapIndicator: $showClapIndicator, clapProgress: $clapProgress)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView

        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported on this device.")
            return arView
        }

        let configuration = ARFaceTrackingConfiguration()
        arView.session.run(configuration)


        do {
            let ghostModel = try Entity.load(named: "Cute_ghost")
            ghostModel.scale = SIMD3<Float>(0.0005, 0.0005, 0.0005)

            // Meng-generate collision bounds agar model ini bisa dideteksi oleh ketukan jari (tap / hit-test)
            ghostModel.generateCollisionShapes(recursive: true)
            
            // Tempatkan di belakang kepala (initial position)
            ghostModel.position = SIMD3<Float>(0, 0, -0.3)

            let faceAnchor = AnchorEntity(.face)
            faceAnchor.addChild(ghostModel)
            arView.scene.addAnchor(faceAnchor)

            context.coordinator.ghostModel = ghostModel
            context.coordinator.faceAnchor = faceAnchor
            context.coordinator.startOrbitAnimation()

        } catch {
            print("Failed to load ghost model: \(error)")
            let fallbackModel = Entity()
            context.coordinator.ghostModel = fallbackModel
        }

        // --- TAMBAHKAN TAP GESTURE RECOGNIZER ---
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject {
        @Binding var showGhostInfo: Bool
        @Binding var handPosition: CGPoint?
        @Binding var showClapIndicator: Bool
        @Binding var clapProgress: CGFloat
        var arView: ARView?
        
        var ghostModel: Entity?
        var faceAnchor: AnchorEntity?
        var displayLink: CADisplayLink?
        var startTime: CFTimeInterval = 0

        let orbitRadius: Float = 0.05
        let orbitHeight: Float = 0.20
        let orbitSpeed: Float = 2.2

        var phase: AnimationPhase = .waiting
        var riseStartTime: CFTimeInterval = 0
        let riseDuration: CFTimeInterval = 2.0
        
        // --- HAND TRACKING ---
        private let handPoseRequest = VNDetectHumanHandPoseRequest()
        private let visionQueue = DispatchQueue(label: "com.ar2.visionQueue", qos: .userInitiated)
        private var lastVisionTime: CFTimeInterval = 0
        private let visionInterval: CFTimeInterval = 0.08 // Proses tiap ~80ms (12fps) — hemat CPU
        private let punchVelocityThreshold: CGFloat = 1.5 // Kecepatan minimum pukulan
        private var canPunch: Bool = true // Cooldown supaya tidak spam
        
        // Buffer posisi untuk kalkulasi arah yang lebih akurat
        private var handHistory: [(position: CGPoint, time: CFTimeInterval)] = []
        private let historySize = 5
        private var smoothedHandPosition: CGPoint? // Untuk filter anti-getar (EMA)
        
        // --- KNOCKED AWAY ANIMATION ---
        var knockDirection: SIMD3<Float> = .zero
        var knockStartTime: CFTimeInterval = 0
        let knockDuration: CFTimeInterval = 0.5  // Durasi terlempar
        let returnDelay: CFTimeInterval = 1.0      // Delay sebelum kembali
        let returnDuration: CFTimeInterval = 1.5   // Durasi kembali
        var returnStartTime: CFTimeInterval = 0
        let knockDistance: Float = 0.35             // Seberapa jauh terlempar
        // Posisi diam hantu (target akhir rising)
        let stationaryPosition = SIMD3<Float>(0, 0.20, -0.05)

        // --- TRANSFORMASI (CLAP) ---
        var canTransform: Bool = true
        var handsClapStartTime: CFTimeInterval?
        let handsClapThreshold: CGFloat = 0.20 // Jarak yang dianggap "bersatu" (normalized)
        let handsClapDuration: CFTimeInterval = 0.8 // Harus ditahan selama 0.8 detik
        var currentGhostForm: Int = 0 
        var smokeEntity: Entity?
        var transformStartTime: CFTimeInterval = 0
        let transformDuration: CFTimeInterval = 2.0
        
        // --- ASYNC MODEL LOADING ---
        var loadCancellable: AnyCancellable?
        // Daftar nama model yang akan ditukar (Hanya Cute_ghost dan Scary_ghost untuk saat ini)
        let ghostModelNames = ["Cute_ghost", "Scary_ghost"]
        // Pengaturan skala spesifik untuk masing-masing hantu. Ganti ukurannya di sini!
        let ghostScales: [String: Float] = [
            "Cute_ghost": 0.0005,
            "Scary_ghost": 0.002 // << UBAH ANGKA INI UNTUK MEMBESARKAN SCARY_GHOST
        ]
        var isModelLoaded: Bool = true // Untuk menahan animasi muncul sampai model selesai di-load

        enum AnimationPhase {
            case waiting
            case rising
            case stationary
            case knockedAway   // Terlempar karena dipukul
            case returning     // Kembali melayang ke posisi semula
            case transforming  // Berubah wujud (Clap)
        }
        
        init(showGhostInfo: Binding<Bool>, handPosition: Binding<CGPoint?>, showClapIndicator: Binding<Bool>, clapProgress: Binding<CGFloat>) {
            self._showGhostInfo = showGhostInfo
            self._handPosition = handPosition
            self._showClapIndicator = showClapIndicator
            self._clapProgress = clapProgress
            handPoseRequest.maximumHandCount = 2 // UPDATE: Deteksi 2 tangan
            super.init()
        }
        
        // MARK: - ARSessionDelegate (Hand Detection — Reliable)
        
        /// Dipanggil dari updateAnimation saat phase == .stationary
        func processHandDetection() {
            guard canPunch, phase == .stationary else { return }
            guard let arView = arView,
                  let currentFrame = arView.session.currentFrame else { return }
            
            // Throttle: proses tiap ~80ms, bukan setiap frame
            let now = CACurrentMediaTime()
            guard now - lastVisionTime > visionInterval else { return }
            lastVisionTime = now
            
            let pixelBuffer = currentFrame.capturedImage
            

            // Proses Vision di background thread agar TIDAK memblokir render AR
            visionQueue.async { [weak self] in
                guard let self = self else { return }
                
                // .leftMirrored = putar 90 CCW + mirror. Ini membuat orientasi ML model
                // sama PERSIS dengan apa yang kita lihat di layar portrait front camera!
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
                
                do {
                    try handler.perform([self.handPoseRequest])
                    
                    guard let results = self.handPoseRequest.results, !results.isEmpty else {
                        // Tidak ada tangan
                        self.smoothedHandPosition = nil
                        self.handHistory.removeAll()
                        DispatchQueue.main.async { [weak self] in
                            self?.handPosition = nil
                            self?.showClapIndicator = false
                            self?.clapProgress = 0.0
                        }
                        self.handsClapStartTime = nil
                        return
                    }
                    
                    if results.count >= 2 {
                        // --- DETEKSI GESTUR CLAP (DUA TANGAN) ---
                        let hand1Opt = self.getBestHandPoint(from: results[0])
                        let hand2Opt = self.getBestHandPoint(from: results[1])
                        
                        if let hand1 = hand1Opt, let hand2 = hand2Opt {
                            let dx = hand1.x - hand2.x
                            let dy = hand1.y - hand2.y
                            let distance = sqrt(dx*dx + dy*dy)
                            
                            if distance < self.handsClapThreshold && self.canTransform {
                                let currentTime = CACurrentMediaTime()
                                if self.handsClapStartTime == nil {
                                    self.handsClapStartTime = currentTime
                                }
                                
                                let elapsed = currentTime - self.handsClapStartTime!
                                let progress = min(CGFloat(elapsed / self.handsClapDuration), 1.0)
                                
                                DispatchQueue.main.async { [weak self] in
                                    self?.showClapIndicator = true
                                    self?.clapProgress = progress
                                }
                                
                                if progress >= 1.0 {
                                    DispatchQueue.main.async { [weak self] in
                                        self?.showClapIndicator = false
                                        self?.clapProgress = 0.0
                                        self?.triggerTransformation()
                                    }
                                    self.handsClapStartTime = nil
                                }
                                // Skip punch logic saat sedang clamp/clap
                                return
                            } else {
                                self.handsClapStartTime = nil
                                DispatchQueue.main.async { [weak self] in
                                    self?.showClapIndicator = false
                                    self?.clapProgress = 0.0
                                }
                            }
                        }
                    } else {
                        // Hanya satu tangan terdeteksi, batalkan clap
                        self.handsClapStartTime = nil
                        DispatchQueue.main.async { [weak self] in
                            self?.showClapIndicator = false
                            self?.clapProgress = 0.0
                        }
                    }
                    
                    // --- DETEKSI PUNCH LOGIC (Gunakan tangan pertama/terbaik) ---
                    guard let observation = results.first, let point = self.getBestHandPoint(from: observation) else {
                        self.smoothedHandPosition = nil
                        self.handHistory.removeAll()
                        DispatchQueue.main.async { [weak self] in
                            self?.handPosition = nil
                        }
                        return
                    }
                    
                    // Inversi X agar sesuai dengan efek "kaca" (mirror) di kamera depan
                    let mirroredPoint = CGPoint(x: 1.0 - point.x, y: point.y)
                    
                    // Smoothing (Low-pass filter / EMA) agar pergerakan tidak bergetar dan sangat mulus
                    let smoothedPoint: CGPoint
                    if let prev = self.smoothedHandPosition {
                        // Blend: 40% posisi baru, 60% posisi lama
                        let alpha: CGFloat = 0.4
                        smoothedPoint = CGPoint(
                            x: prev.x + alpha * (mirroredPoint.x - prev.x),
                            y: prev.y + alpha * (mirroredPoint.y - prev.y)
                        )
                    } else {
                        smoothedPoint = mirroredPoint
                    }
                    self.smoothedHandPosition = smoothedPoint
                    
                    // Update posisi visual debug di layer UI
                    DispatchQueue.main.async { [weak self] in
                        self?.handPosition = smoothedPoint
                    }
                    
                    let currentTime = CACurrentMediaTime()
                    
                    // Tambah ke buffer history (menggunakan koordinat tersmoothing)
                    self.handHistory.append((position: smoothedPoint, time: currentTime))
                    if self.handHistory.count > self.historySize {
                        self.handHistory.removeFirst()
                    }
                    
                    // Butuh minimal 2 entry untuk menghitung velocity
                    if self.handHistory.count >= 2 {
                        let oldest = self.handHistory.first!
                        let newest = self.handHistory.last!
                        
                        let dt = newest.time - oldest.time
                        guard dt > 0.01 else { return }
                        
                        let dx = newest.position.x - oldest.position.x
                        let dy = newest.position.y - oldest.position.y
                        let velocity = sqrt(dx * dx + dy * dy) / CGFloat(dt)
                        
                        // Cek apakah tangan berada di zona ghost (bagian atas layar, tengah)
                        // Ghost berada kira-kira di 15-35% dari atas layar, 30-70% horizontal
                        let handX = newest.position.x
                        let handY = newest.position.y // Vision: 0 = bawah, 1 = atas
                        let isNearGhost = handY > 0.55 && handX > 0.25 && handX < 0.75
                        
                        // Threshold dinamis: lebih mudah memukul jika tangan dekat ghost!
                        let activeThreshold: CGFloat = isNearGhost ? 0.5 : self.punchVelocityThreshold
                        
                        // print log dihide agar tidak spam
                        
                        // Jika kecepatan tangan melebihi threshold = PUKULAN!
                        if velocity > activeThreshold {
                            let length = sqrt(dx * dx + dy * dy)
                            guard length > 0.001 else { return }
                            
                            // Karena koordinat sudah .leftMirrored + mirror (sesuai layar):
                            // dx positif = ke kanan layar = ke kanan AR (sama)
                            // dy positif = ke ATAS dari sudut pandang Vision
                            // Arah AR Y positif = ke ATAS
                            let normalizedDx = Float(dx / length)
                            let normalizedDy = Float(dy / length)
                            
                            let direction = SIMD3<Float>(normalizedDx, normalizedDy, 0)
                            
                            print("👊 PUNCH! velocity=\(String(format: "%.2f", velocity)) direction=\(direction) nearGhost=\(isNearGhost)")
                            
                            DispatchQueue.main.async { [weak self] in
                                self?.triggerKnockAway(direction: direction)
                                self?.handHistory.removeAll()
                            }
                        }
                    }
                    
                } catch {
                    print("❌ Vision error: \(error)")
                }
            }
        }
        
        /// Ambil rata-rata dari 11 titik (tengah telapak & 2 sendi per jari) untuk akurasi tertinggi
        private func getBestHandPoint(from observation: VNHumanHandPoseObservation) -> CGPoint? {
            // 11 Titik Polygon seperti yang diminta: 
            // - Wrist (1)
            // - Masing-masing 2 sendi pangkal dari tiap jari (10)
            let jointsToTry: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbMP, .thumbIP,
                .indexMCP, .indexPIP,
                .middleMCP, .middlePIP,
                .ringMCP, .ringPIP,
                .littleMCP, .littlePIP
            ]
            
            var validPoints: [CGPoint] = []
            
            for joint in jointsToTry {
                // Confidence filter di set ke 0.5. Karena kita ambil rata-rata dari banyak titik, 
                // tracking akan jauh lebih kebal terhadap kesalahan deteksi 1-2 titik acak.
                if let point = try? observation.recognizedPoint(joint),
                   point.confidence > 0.5 {
                    validPoints.append(CGPoint(x: point.location.x, y: point.location.y))
                }
            }
            
            // Minimal harus ada 4 titik yang terdeteksi valid agar bisa dihitung sebagai tangan
            guard validPoints.count >= 4 else {
                return nil
            }
            
            // Rata-ratakan posisi SEMUA 11 titik poligon (Center of Mass)
            // Ini akan membuat tracking SANGAT lengket dan stabil di tengah telapak tangan
            let avgX = validPoints.map { $0.x }.reduce(0, +) / CGFloat(validPoints.count)
            let avgY = validPoints.map { $0.y }.reduce(0, +) / CGFloat(validPoints.count)
            
            return CGPoint(x: avgX, y: avgY)
        }
        
        // MARK: - Punch Trigger
        
        func triggerKnockAway(direction: SIMD3<Float>) {
            guard phase == .stationary, canPunch else { return }
            
            canPunch = false
            knockDirection = direction
            knockStartTime = CACurrentMediaTime()
            phase = .knockedAway
            
            // Memainkan efek suara pukulan (SFX)
            SoundManager.shared.play(.punch)
            
            print("👊 PUNCH! Direction: \(direction)")
        }
        
        // MARK: - Transformation Logic
        
        func triggerTransformation() {
            guard phase == .stationary, canTransform else { return }
            
            canTransform = false
            canPunch = false // Disable punch during transformation
            transformStartTime = CACurrentMediaTime()
            phase = .transforming
            isModelLoaded = false // Beri tahu sistem bahwa kita sedang menunggu model baru
            
            // Advance to the next form
            currentGhostForm = (currentGhostForm + 1) % ghostModelNames.count
            let newModelName = ghostModelNames[currentGhostForm]
            
            createSmokeEffect()
            
            // Memainkan efek suara transformasi mistis
            SoundManager.shared.play(.transform)
            
            print("✨ TRANSFORM! Memuat model: \(newModelName)")
            
            // Load secara asinkron (di background) agar AR tidak freeze
            loadCancellable = Entity.loadAsync(named: newModelName)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("❌ Gagal memuat model \(newModelName). Error: \(error)")
                        // Jika gagal, anggap sudah selesai agar animasi bisa lanjut (meski menggunakan model lama)
                        self.isModelLoaded = true 
                    }
                }, receiveValue: { [weak self] newEntity in
                    guard let self = self, let faceAnchor = self.faceAnchor else { return }
                    
                    // Kita tak bisa langsung pasang karena harus menunggu hantu lama "tenggelam" ke dalam asap 
                    // di animasi (tunggu sekitar 1 detik/setengah perjalanan transformasi).
                    // Namun kita simpan dan tukar di tengah animasi updateTimer. 
                    // Untuk lebih mulusnya, segera tukar dan set skalanya jadi 0.
                    
                    // Hilangkan yang lama
                    self.ghostModel?.removeFromParent()
                    
                    // Konfigurasi standar hantu baru
                    newEntity.scale = SIMD3<Float>(repeating: 0.0001) // Super kecil dulu (disembunyikan di dalam asap)
                    newEntity.position = self.stationaryPosition
                    newEntity.generateCollisionShapes(recursive: true)
                    
                    faceAnchor.addChild(newEntity)
                    self.ghostModel = newEntity
                    
                    self.isModelLoaded = true // Animasi scale-up sekarang boleh berjalan penuh
                    print("✅ \(newModelName) berhasil dimuat dan dipasang!")
                })
        }
        
        func createSmokeEffect() {
            guard let faceAnchor = faceAnchor else { return }
            
            let smoke = Entity()
            var particles = ParticleEmitterComponent()
            
            particles.emitterShape = .sphere
            particles.emitterShapeSize = [0.03, 0.03, 0.03]
            
            particles.mainEmitter.birthRate = 300
            particles.mainEmitter.lifeSpan = 1.5
            particles.mainEmitter.size = 0.01
            particles.mainEmitter.sizeVariation = 0.04
            
            particles.mainEmitter.color = .evolving(
                start: .single(.init(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.8)),
                end: .single(.init(red: 0.3, green: 0.0, blue: 0.0, alpha: 0.0))
            )
            
            particles.mainEmitter.isLightingEnabled = false
            smoke.components.set(particles)
            
            smoke.position = stationaryPosition
            faceAnchor.addChild(smoke)
            self.smokeEntity = smoke
            
            // Hapus asap setelah 2 detik
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.removeSmokeEffect()
            }
        }
        
        func removeSmokeEffect() {
            smokeEntity?.removeFromParent()
            smokeEntity = nil
        }
        
        // --- DETEKSI KETUKAN JARI (HIT TEST) ---
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let tapLocation = recognizer.location(in: arView)
            
            // Sentuhan di tempat kosong, sembunyikan info
            if arView.entity(at: tapLocation) == nil {
                withAnimation {
                    showGhostInfo = false
                }
            }
        }

        func startOrbitAnimation() {
            phase = .waiting

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.phase = .rising
                self.riseStartTime = CACurrentMediaTime()
                self.displayLink = CADisplayLink(target: self, selector: #selector(self.updateAnimation))
                self.displayLink?.add(to: .main, forMode: .default)
            }
        }

        @objc func updateAnimation(displayLink: CADisplayLink) {
            guard let ghostModel = ghostModel else { return }

            let currentTime = CACurrentMediaTime()
            let shakeSpeed: Double = .pi * 2.0
            let shakeAngle: Float = 15 * (.pi / 180)
            let currentYaw = Float(sin(currentTime * shakeSpeed)) * shakeAngle
            
            // Konfigurasi scale dinamis berdasarkan model yang aktif
            let activeModelName = ghostModelNames[currentGhostForm]
            let activeBaseScale = ghostScales[activeModelName] ?? 0.0005

            switch phase {
            case .waiting:
                break

            case .rising:
                let elapsed = currentTime - riseStartTime
                let progress = min(Float(elapsed / riseDuration), 1.0)

                let eased = progress < 0.5
                    ? 2 * progress * progress
                    : 1 - pow(-2 * progress + 2, 2) / 2

                let startZ: Float = -0.1
                let targetZ: Float = -0.05
                let z = startZ + (targetZ - startZ) * eased
                let y = orbitHeight * eased

                ghostModel.position = SIMD3<Float>(0, y, z)
                
                let pitch: Float = 19 * (.pi / 180)
                ghostModel.transform.rotation = simd_quatf(angle: currentYaw, axis: [0, 1, 0])
                    * simd_quatf(angle: pitch, axis: [1, 0, 0])

                if progress >= 1.0 {
                    phase = .stationary
                }

            case .stationary:
                // Deteksi tangan setiap frame (throttled di dalam method)
                processHandDetection()
                
                let pitch: Float = 19 * (.pi / 180)
                ghostModel.transform.rotation = simd_quatf(angle: currentYaw, axis: [0, 1, 0])
                    * simd_quatf(angle: pitch, axis: [1, 0, 0])
                
            case .knockedAway:
                let elapsed = currentTime - knockStartTime
                let progress = min(Float(elapsed / knockDuration), 1.0)
                
                // Easing: fast start, ease out (efek terlempar)
                let eased = 1 - pow(1 - progress, 3)
                
                // Posisi terlempar dari posisi diam
                let knockOffset = knockDirection * knockDistance * eased
                ghostModel.position = stationaryPosition + knockOffset
                
                // Efek tumble berputar lucu — berputar cepat di sumbu pukulan
                let tumbleAngle = eased * .pi * 4 // Putar 2x full rotation
                let tumbleAxis = SIMD3<Float>(-knockDirection.y, knockDirection.x, 0.3)
                let tumbleRotation = simd_quatf(angle: tumbleAngle, axis: normalize(tumbleAxis))
                
                // Scale membesar saat shock, lalu mengecil
                let scaleShock: Float = 1.0 + 0.3 * sin(eased * .pi)
                ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale * scaleShock)
                
                ghostModel.transform.rotation = tumbleRotation
                
                // Setelah selesai terlempar, mulai delay sebelum kembali
                if progress >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + returnDelay) { [weak self] in
                        guard let self = self else { return }
                        self.returnStartTime = CACurrentMediaTime()
                        self.phase = .returning
                    }
                }
                
            case .returning:
                let elapsed = currentTime - returnStartTime
                let progress = min(Float(elapsed / returnDuration), 1.0)
                
                // Base easing: cubic ease-out — monoton naik dari 0 ke 1, TIDAK pernah overshoot
                let baseEased = 1 - pow(1 - progress, 3)
                
                // Wobble sebagai offset KECIL yang di-overlay, bukan bagian dari interpolasi utama
                // Amplitude mengecil seiring waktu (decay), jadi wobble hilang menjelang akhir
                let wobbleDecay = (1 - progress) * (1 - progress) // makin kecil mendekati 1
                let wobbleOffset = wobbleDecay * 0.08 * sin(progress * .pi * 5)
                
                // Posisi kembali dari knockedAway ke stationaryPosition
                let knockedPosition = stationaryPosition + knockDirection * knockDistance
                // Interpolasi utama + wobble kecil sepanjang arah knock
                let mainPos = knockedPosition + (stationaryPosition - knockedPosition) * baseEased
                let wobbleVec = knockDirection * wobbleOffset
                ghostModel.position = mainPos + wobbleVec
                
                // Rotasi wobble lucu saat kembali (bergoyang makin pelan)
                let wobbleAngle = wobbleDecay * 0.4 * sin(Float(elapsed) * 10)
                let pitch: Float = 19 * (.pi / 180)
                ghostModel.transform.rotation = simd_quatf(angle: currentYaw + wobbleAngle, axis: [0, 1, 0])
                    * simd_quatf(angle: pitch, axis: [1, 0, 0])
                
                // Scale kembali normal dengan sedikit bounce yang decay
                let scaleBounce: Float = 1.0 + wobbleDecay * 0.12 * sin(progress * .pi * 4)
                ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale * scaleBounce)
                
                if progress >= 1.0 {
                    // Kembali ke posisi normal sempurna
                    ghostModel.position = stationaryPosition
                    ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale)
                    phase = .stationary
                    
                    // Cooldown selesai, bisa dipukul lagi
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.canPunch = true
                        self?.handHistory.removeAll()
                    }
                }
                
            case .transforming:
                let elapsed = currentTime - transformStartTime
                let progress = min(Float(elapsed / transformDuration), 1.0)
                
                // Efek scale masuk ke dalam asap (shrink) -> menunggu model -> muncul dari asap (grow)
                var scaleProgress: Float = 0.0
                
                if progress < 0.5 {
                    // Shrink to 0: 0.0 to 0.5 becomes 1.0 to 0.0
                    let p = progress * 2.0
                    scaleProgress = 1.0 - p * p
                    
                    // Putar lebih cepat selagi tersedot asap
                    let spinAngle = Float(elapsed) * 15.0
                    let pitch: Float = 19 * (.pi / 180)
                    ghostModel.transform.rotation = simd_quatf(angle: currentYaw + spinAngle, axis: [0, 1, 0])
                        * simd_quatf(angle: pitch, axis: [1, 0, 0])
                        
                    ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale * max(scaleProgress, 0.001))
                    
                } else {
                    // Tahan scale di 0 jika model belum selesai di-load secara asinkron dari disk
                    if isModelLoaded {
                        // Grow to 1: 0.5 to 1.0 becomes 0.0 to 1.0 bouncing
                        let p = (progress - 0.5) * 2.0
                        let bounce = Float(sin(Double(p) * .pi * 2.5) * exp(-Double(p) * 3.0)) // Bouncy effect
                        scaleProgress = p + bounce * 0.3
                        
                        ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale * max(scaleProgress, 0.001))
                        
                        // Kembalikan rotasi normal santai saat muncul
                        let pitch: Float = 19 * (.pi / 180)
                        ghostModel.transform.rotation = simd_quatf(angle: currentYaw, axis: [0, 1, 0])
                            * simd_quatf(angle: pitch, axis: [1, 0, 0])
                    } else {
                        // Tetap sembunyikan ghost di dalam asap jika load lelet
                        ghostModel.scale = SIMD3<Float>(repeating: 0.0001)
                        // Reset waktu agar tidak kebablasan ke progress 1.0 sebelum model baru muncul
                        transformStartTime = currentTime - (transformDuration * 0.49)
                    }
                }
                
                
                if progress >= 1.0 && isModelLoaded {
                    phase = .stationary
                    canPunch = true
                    ghostModel.scale = SIMD3<Float>(repeating: activeBaseScale)
                    
                    // Cooldown sebelum bisa transform lagi (3 detik)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.canTransform = true
                    }
                }
            }
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}
