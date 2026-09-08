import DefaultAppsCore
import SwiftUI

// not a List: SwiftUI's table bridging logs a reentrancy warning, promised to
// become an assert, once a List holds more than about a hundred rows
struct EntryList<Row: View>: View {
    let groups: [FamilyGroup]
    var headers = true
    @ViewBuilder let row: (SnapshotEntry) -> Row

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groups, id: \.name) { group in
                    Section {
                        ForEach(group.entries, id: \.target.displayString) { entry in
                            row(entry)
                                .padding(.horizontal, 16)
                            Divider()
                                .padding(.leading, 16)
                        }
                    } header: {
                        if headers {
                            Text(tKey(group.name))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                                .background(.background)
                        }
                    }
                }
            }
        }
    }
}
