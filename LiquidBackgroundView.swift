import SwiftUI

/// 液体が揺れるような抽象的なアニメーション背景
struct LiquidBackgroundView: View {
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { context in
            Canvas(opaque: false) { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                
                // 3つの波形レイヤー
                drawWave(
                    in: ctx,
                    size: size,
                    time: time,
                    speed: 0.3,
                    amplitude: 30,
                    frequency: 2,
                    color: Color.brandGreen.opacity(0.03)
                )
                
                drawWave(
                    in: ctx,
                    size: size,
                    time: time + 100,
                    speed: 0.4,
                    amplitude: 40,
                    frequency: 3,
                    color: Color.brandGreen.opacity(0.02)
                )
                
                drawWave(
                    in: ctx,
                    size: size,
                    time: time + 200,
                    speed: 0.2,
                    amplitude: 50,
                    frequency: 1.5,
                    color: Color.brandGreen.opacity(0.015)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func drawWave(
        in context: GraphicsContext,
        size: CGSize,
        time: Double,
        speed: Double,
        amplitude: CGFloat,
        frequency: Double,
        color: Color
    ) {
        var path = Path()
        let midY = size.height / 2
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        for x in stride(from: 0.0, through: Double(size.width), by: 2.0) {
            let relativeX = x / Double(size.width)
            let wave = sin((relativeX * frequency * 2.0 * .pi) + (time * speed))
            let y = Double(midY) + (wave * Double(amplitude))
            path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        }
        
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        
        context.fill(path, with: .color(color))
    }
}

#if DEBUG
struct LiquidBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            LiquidBackgroundView()
        }
    }
}
#endif

