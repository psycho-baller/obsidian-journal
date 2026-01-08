import SwiftUI

struct ArchiveListView: View {
    @ObservedObject var draftManager: DraftManager
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
                    .contentShape(Rectangle()) // Make entire row tappable
                    .onTapGesture {
                        // 1. Restore & Edit
                        restoreAndOpen(draft)
                    }
                    .contextMenu {
                        // 2. Hold to Preview (Context Menu default behavior is preview-like)
                        Button {
                            restoreAndOpen(draft)
                        } label: {
                            Label("Restore & Edit", systemImage: "pencil")
                        }

                        // Valid context menu usually shows content automatically if using standard List
                        // We can add a "Copy" text option too
                        Button {
                            UIPasteboard.general.string = draft.content
                        } label: {
                            Label("Copy Text", systemImage: "doc.on.doc")
                        }
                    } preview: {
                        // Custom preview content
                        ScrollView {
                            Text(draft.content)
                                .padding()
                                .font(.body)
                        }
                        .frame(minWidth: 300, minHeight: 400)
                    }
                    .swipeActions(edge: .leading) {
                        // 3. Swipe Right -> Restore (Move to drafts)
                        Button {
                            withAnimation {
                                draftManager.restoreDraft(draft)
                            }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let sortedDrafts = draftManager.archivedDrafts.sorted(by: { $0.modifiedAt > $1.modifiedAt })
                        if index < sortedDrafts.count {
                            let draft = sortedDrafts[index]
                            draftManager.deleteDraft(draft)
                        }
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

    private func restoreAndOpen(_ draft: Draft) {
        draftManager.restoreDraft(draft)
        draftManager.selectDraft(draft)
        isPresented = false
    }
}
