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

struct PatternPickerView_Previews: PreviewProvider {
    static var previews: some View {
        PatternPickerView(onSelect: { _ in })
    }
}

