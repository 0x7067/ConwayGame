import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conway's Game of Life")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Created by Pedro Guimarães")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("This app simulates Conway's Game of Life, a zero-player cellular automaton where simple rules give rise to complex patterns. You can create boards, step through generations, and explore common patterns.")
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
                    Text("Design and development by Pedro Guimarães. Built with SwiftUI.")
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

