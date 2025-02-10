import SwiftUI
import AVFoundation

struct CustomVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity
    
    init(player: AVPlayer, gravity: AVLayerVideoGravity = .resizeAspectFill) {
        self.player = player
        self.gravity = gravity
        print("🎮 [CustomVideoPlayer]: Initialized with player: \(player)")
    }
    
    func makeUIView(context: Context) -> PlayerView {
        print("🎮 [CustomVideoPlayer]: Creating PlayerView")
        let view = PlayerView()
        view.player = player
        view.playerLayer.videoGravity = gravity
        print("✅ [CustomVideoPlayer]: PlayerView created and configured")
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        print("🔄 [CustomVideoPlayer]: Updating PlayerView")
        print("  - Old player: \(String(describing: uiView.player))")
        print("  - New player: \(String(describing: player))")
        uiView.player = player
        uiView.playerLayer.videoGravity = gravity
    }
}

class PlayerView: UIView {
    // Required to use AVPlayerLayer
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
} 