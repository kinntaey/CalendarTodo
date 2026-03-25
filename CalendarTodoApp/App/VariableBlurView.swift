import SwiftUI

#if canImport(UIKit)
import UIKit

/// 상단 그라데이션 블러 뷰
/// - CalendarContainerView.swift 에서 사용
/// - 스크롤 시 status bar 뒤 콘텐츠를 블러 처리
struct VariableBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        // 블러 스타일 변경: .systemUltraThinMaterial (약함) → .systemThickMaterial (강함)
        // 다른 옵션: .systemThinMaterial, .systemMaterial, .systemChromeMaterial
        let blurEffect = UIBlurEffect(style: .systemChromeMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)

        // 그라데이션 마스크: 위에서 아래로 블러가 점점 사라지게
        let maskLayer = CAGradientLayer()
        // 위 100% → 아래 0% 으로 선형 그라데이션
        maskLayer.colors = [
            UIColor.black.cgColor,              // 맨 위: 블러 100%
            UIColor.clear.cgColor               // 맨 아래: 블러 0%
        ]
        maskLayer.locations = [0.0, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1)
        blurView.layer.mask = maskLayer

        return blurView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // 뷰 크기 변경 시 마스크 크기도 맞춤
        DispatchQueue.main.async {
            uiView.layer.mask?.frame = uiView.bounds
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct VariableBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let blurView = NSVisualEffectView()
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active

        let maskLayer = CAGradientLayer()
        maskLayer.colors = [
            NSColor.black.cgColor,
            NSColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1)
        blurView.wantsLayer = true
        blurView.layer?.mask = maskLayer

        return blurView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        DispatchQueue.main.async {
            nsView.layer?.mask?.frame = nsView.bounds
        }
    }
}
#endif
