import SwiftUI

struct PortalView: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(startDate)

            GeometryReader { geometry in
                Rectangle()
                    .fill(.white) // Base color for the shader
                    .colorEffect(
                        ShaderLibrary.portalShader(
                            .float2(geometry.size.width, geometry.size.height),
                            .float(time)
                        )
                    )
            }
        }
        .clipShape(Circle())
    }
}

struct PortalView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PortalView()
                .frame(width: 300, height: 300)
        }
    }
}
