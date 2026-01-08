import SwiftUI

struct ArchiveListView: View {
    @ObservedObject var draftManager: DraftManager // Now uses DraftManager source of truth
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            List {
                // Filter explicitly for .archived status
                ForEach(draftManager.archivedDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { draft in
                    VStack(alignment: .leading) {
                        Text(draft.content)
                            .lineLimit(2)
                            .font(.body)
                        Text("Archived on " + draft.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let draft = draftManager.archivedDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })[index]
                        draftManager.deleteDraft(draft)
                    }
                }
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .overlay {
                if draftManager.archivedDrafts.isEmpty {
                    VStack {
                        Image(systemName: "archivebox")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No archived entries yet")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
