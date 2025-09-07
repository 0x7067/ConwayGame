import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conway's Game of Life")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("A Cellular Automaton Simulator")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Conway's Game of Life is a zero-player cellular automaton devised by mathematician John Conway in 1970. Despite its simple rules, it's capable of universal computation—meaning it's Turing complete and can simulate any computer program.")
                        .lineSpacing(4)
                    Text("This implementation lets you create boards, step through generations, explore famous patterns, and witness how complex behaviors emerge from simple rules.")
                        .lineSpacing(4)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How It Works")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Each cell lives on a grid. In each generation:")
                        .lineSpacing(4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• A live cell survives with 2–3 neighbors")
                        Text("• A dead cell becomes alive with exactly 3 neighbors")
                        Text("• Otherwise it stays or becomes dead")
                    }
                    .padding(.leading, 8)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Credits")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Original game concept by John Conway (1970). This iOS implementation designed and developed by Pedro Guimarães using SwiftUI.")
                        .lineSpacing(4)
                }
                
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .navigationTitle("About")
    }
}

#Preview {
    AboutView()
}

