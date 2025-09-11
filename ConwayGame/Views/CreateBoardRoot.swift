import SwiftUI
import FactoryKit

struct CreateBoardRoot: View {
    var onCreated: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CreateBoardView(onCreated: { id in
                onCreated?(id)
            })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    CreateBoardRoot()
}
