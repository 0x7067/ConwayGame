import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Conway's Game of Life")
                    .font(.title)
                Text("Created by Pedro Guimarães")
                    .font(.headline)
                Text("About")
                    .font(.title3)
                Text("This app simulates Conway's Game of Life, a zero-player cellular automaton where simple rules give rise to complex patterns. You can create boards, step through generations, and explore common patterns.")
                Divider()
                Text("How It Works")
                    .font(.title3)
                Text("Each cell lives on a grid. In each generation: a live cell survives with 2–3 neighbors; a dead cell becomes alive with exactly 3 neighbors; otherwise it stays or becomes dead.")
                Divider()
                Text("Credits")
                    .font(.title3)
                Text("Design and development by Pedro Guimarães. Built with SwiftUI.")
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View { AboutView() }
}

