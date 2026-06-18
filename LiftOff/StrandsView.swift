// StrandsView.swift
// Picksy
//
// Metal port of the Strands WebGL animation from reactbits.dev.
// Usage: StrandsView() as a background or overlay in any SwiftUI view.

import SwiftUI
import MetalKit

// MARK: - Uniforms
// Layout must match StrandsUniforms in Strands.metal exactly.

private struct StrandsUniforms {
    var time:        Float = 0
    var _pad:        Float = 0
    var resolution:  SIMD2<Float> = .zero
    // 8 × float4 color slots (w unused) — 16-byte aligned after resolution
    var c0: SIMD4<Float> = .zero
    var c1: SIMD4<Float> = .zero
    var c2: SIMD4<Float> = .zero
    var c3: SIMD4<Float> = .zero
    var c4: SIMD4<Float> = .zero
    var c5: SIMD4<Float> = .zero
    var c6: SIMD4<Float> = .zero
    var c7: SIMD4<Float> = .zero
    var colorCount:  Int32 = 0
    var strandCount: Int32 = 3
    var speed:       Float = 0.5
    var amplitude:   Float = 1
    var waviness:    Float = 1
    var thickness:   Float = 0.7
    var glow:        Float = 2.6
    var taper:       Float = 3
    var spread:      Float = 1
    var hueShift:    Float = 0
    var intensity:   Float = 0.6
    var opacity:     Float = 1
    var scale:       Float = 1.5
    var saturation:  Float = 2
}

// MARK: - Renderer

private final class StrandsRenderer: NSObject, MTKViewDelegate {

    private let commandQueue: MTLCommandQueue
    private let pipeline:     MTLRenderPipelineState
    private let startTime =   Date()

    // Props (written from main thread, read on render thread — fine for Float/Int)
    var colors:      [Color] = []
    var strandCount: Int     = 3
    var speed:       Float   = 0.5
    var amplitude:   Float   = 1
    var waviness:    Float   = 1
    var thickness:   Float   = 0.7
    var glow:        Float   = 2.6
    var taper:       Float   = 3
    var spread:      Float   = 1
    var hueShift:    Float   = 0
    var intensity:   Float   = 0.6
    var opacity:     Float   = 1
    var scale:       Float   = 1.5
    var saturation:  Float   = 2

    init?(view: MTKView) {
        guard let device = view.device,
              let queue  = device.makeCommandQueue(),
              let lib    = device.makeDefaultLibrary(),
              let vert   = lib.makeFunction(name: "strands_vertex"),
              let frag   = lib.makeFunction(name: "strands_fragment")
        else { return nil }

        commandQueue = queue

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vert
        desc.fragmentFunction = frag
        desc.colorAttachments[0].pixelFormat             = view.colorPixelFormat
        desc.colorAttachments[0].isBlendingEnabled       = true
        desc.colorAttachments[0].rgbBlendOperation       = .add
        desc.colorAttachments[0].alphaBlendOperation     = .add
        desc.colorAttachments[0].sourceRGBBlendFactor    = .one
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor  = .one
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let ps = try? device.makeRenderPipelineState(descriptor: desc)
        else { return nil }
        pipeline = ps

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let rpd      = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmd      = commandQueue.makeCommandBuffer(),
              let enc      = cmd.makeRenderCommandEncoder(descriptor: rpd)
        else { return }

        let size = view.drawableSize
        let t    = Float(Date().timeIntervalSince(startTime))

        var u          = StrandsUniforms()
        u.time         = t
        u.resolution   = SIMD2<Float>(Float(size.width), Float(size.height))
        u.strandCount  = Int32(min(strandCount, 12))
        u.speed        = speed
        u.amplitude    = amplitude
        u.waviness     = waviness
        u.thickness    = thickness
        u.glow         = glow
        u.taper        = taper
        u.spread       = spread
        u.hueShift     = hueShift
        u.intensity    = intensity
        u.opacity      = opacity
        u.scale        = scale
        u.saturation   = saturation

        let slots = [u.c0, u.c1, u.c2, u.c3, u.c4, u.c5, u.c6, u.c7]
        let filled = colors.prefix(8).map { toSIMD($0) }
        u.colorCount   = Int32(filled.count)
        if filled.count > 0 { u.c0 = filled[0] }
        if filled.count > 1 { u.c1 = filled[1] }
        if filled.count > 2 { u.c2 = filled[2] }
        if filled.count > 3 { u.c3 = filled[3] }
        if filled.count > 4 { u.c4 = filled[4] }
        if filled.count > 5 { u.c5 = filled[5] }
        if filled.count > 6 { u.c6 = filled[6] }
        if filled.count > 7 { u.c7 = filled[7] }
        _ = slots  // suppress warning

        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&u, length: MemoryLayout<StrandsUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()

        cmd.present(drawable)
        cmd.commit()
    }

    private func toSIMD(_ color: Color) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), 0)
    }
}

// MARK: - SwiftUI View

struct StrandsView: UIViewRepresentable {

    var colors:    [Color] = [.orange, .purple, .cyan]
    var count:     Int     = 3
    var speed:     Float   = 0.5
    var amplitude: Float   = 1.0
    var waviness:  Float   = 1.0
    var thickness: Float   = 0.7
    var glow:      Float   = 2.6
    var taper:     Float   = 3.0
    var spread:    Float   = 1.0
    var hueShift:  Float   = 0.0
    var intensity: Float   = 0.6
    var saturation: Float  = 2.0
    var opacity:   Float   = 1.0
    var scale:     Float   = 1.5

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.backgroundColor       = .clear
        view.isOpaque              = false
        view.clearColor            = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat      = .bgra8Unorm
        view.isPaused              = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60

        let renderer = StrandsRenderer(view: view)
        context.coordinator.renderer = renderer
        view.delegate = renderer
        apply(to: renderer)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        apply(to: context.coordinator.renderer)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func apply(to renderer: StrandsRenderer?) {
        guard let r = renderer else { return }
        r.colors      = colors
        r.strandCount = count
        r.speed       = speed
        r.amplitude   = amplitude
        r.waviness    = waviness
        r.thickness   = thickness
        r.glow        = glow
        r.taper       = taper
        r.spread      = spread
        r.hueShift    = hueShift
        r.intensity   = intensity
        r.opacity     = opacity
        r.scale       = scale
        r.saturation  = saturation
    }

    final class Coordinator {
        var renderer: StrandsRenderer?
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StrandsView(
            colors:    [.orange, Color(red: 0.49, green: 0.23, blue: 0.93), .cyan],
            count:     3,
            speed:     0.5,
            amplitude: 1.0,
            waviness:  1.0,
            thickness: 0.7,
            glow:      2.6
        )
        .ignoresSafeArea()
    }
}
