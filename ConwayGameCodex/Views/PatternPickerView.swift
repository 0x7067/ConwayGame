import SwiftUI

struct PatternPickerView: View {
    let onSelect: (PredefinedPattern) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(PredefinedPattern.allCases) { p in
                Button(action: {
                    onSelect(p)
                    dismiss()
                }) {
                    Text(p.displayName)
                }
            }
        }
        .navigationTitle("Patterns")
    }
}

#Preview {
    PatternPickerView(onSelect: { _ in })
}

