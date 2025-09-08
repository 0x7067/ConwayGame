import SwiftUI
import ConwayGameEngine

struct PatternPickerView: View {
    let onSelect: (Pattern) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Pattern.allCases) { pattern in
                Button(action: {
                    onSelect(pattern)
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.displayName)
                            .font(.headline)
                        Text(pattern.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Patterns")
    }
}

#Preview {
    PatternPickerView(onSelect: { _ in })
}

