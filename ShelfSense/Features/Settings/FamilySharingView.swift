//
//  FamilySharingView.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import CloudKit

struct FamilySharingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HouseholdMember.createdAt) private var members: [HouseholdMember]
    @Query private var households: [Household]

    @State private var cloudService = CloudKitHouseholdService.shared
    @State private var showAdd = false
    @State private var newName = ""
    @State private var sharePayload: SharePayload?
    @State private var isPreparingShare = false
    @State private var errorMessage: String?

    private var household: Household? {
        households.sorted { $0.createdAt < $1.createdAt }.first
    }

    var body: some View {
        List {
            syncSection
            householdSection
            membersSection
            sharedDataSection
            actionsSection
        }
        .navigationTitle("Family Sharing")
        .task {
            cloudService.configure(container: modelContext.container)
            await cloudService.refreshAccountStatus()
            _ = HouseholdBootstrapService.bootstrap(context: modelContext)
            await cloudService.syncSharedData(context: modelContext)
        }
        .alert("Add Member", isPresented: $showAdd) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { newName = "" }
            Button("Add") { addMember() }
        }
        .alert("Family Sharing", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $sharePayload) { payload in
            CloudSharingView(share: payload.share, container: payload.container) {
                sharePayload = nil
            }
        }
    }

    private var syncSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: cloudService.syncStatus.icon)
                    .foregroundStyle(cloudService.syncStatus == .available ? ShelfTheme.success : ShelfTheme.warning)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(cloudService.syncStatus.title)
                        .font(.shelfSubheadline)
                    Text("Shopping lists and meal plans sync with invited family members via iCloud.")
                        .font(.shelfCaption)
                        .foregroundStyle(ShelfTheme.textSecondary)
                }
            }

            if let message = cloudService.lastSyncMessage {
                Text(message)
                    .font(.shelfCaption)
                    .foregroundStyle(ShelfTheme.copperLight)
            }
        }
    }

    private var householdSection: some View {
        Section("Household") {
            if let household {
                LabeledContent("Name", value: household.name)
                LabeledContent("Sharing", value: household.isSharingEnabled ? "Active" : "Private")
                LabeledContent("Members", value: "\(members.count)")
            } else {
                Button {
                    _ = HouseholdBootstrapService.bootstrap(context: modelContext)
                    HapticManager.success()
                } label: {
                    Label("Create Household", systemImage: "house.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        if members.isEmpty {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.largeTitle)
                        .foregroundStyle(ShelfTheme.textTertiary)
                    Text("No family members yet")
                        .font(.shelfHeadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        } else {
            Section("Members") {
                ForEach(members, id: \.id) { member in
                    HStack {
                        Circle()
                            .fill(Color(hex: member.colorHex) ?? ShelfTheme.copper)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(member.name).font(.shelfSubheadline)
                            Text(member.role.title).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        }
                        if member.isCurrentUser {
                            Spacer()
                            Text("You").font(.shelfCaption).foregroundStyle(ShelfTheme.copperLight)
                        }
                    }
                }
                .onDelete(perform: deleteMembers)
            }
        }
    }

    @ViewBuilder
    private var sharedDataSection: some View {
        Section("Shared with Family") {
            Label("Shopping Lists", systemImage: "checklist")
            Label("Meal Plans", systemImage: "calendar")
        }
        Section("Private on Your iCloud") {
            Label("Inventory", systemImage: "archivebox.fill")
            Label("Receipts", systemImage: "doc.text.fill")
            Label("XP & Quests", systemImage: "star.fill")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                showAdd = true
            } label: {
                Label("Add Member", systemImage: "person.badge.plus")
                    .foregroundStyle(ShelfTheme.copperLight)
            }

            Button {
                Task { await inviteFamily() }
            } label: {
                HStack {
                    Label(isPreparingShare ? "Preparing Invite…" : "Invite Family via iCloud", systemImage: "person.2.badge.gearshape.fill")
                    if isPreparingShare {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingShare || cloudService.syncStatus != .available || household == nil)

            Button {
                Task { await cloudService.syncSharedData(context: modelContext) }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(cloudService.syncStatus != .available)

            if members.isEmpty {
                Button {
                    let me = HouseholdMember(name: "Me", role: .owner, isCurrentUser: true)
                    me.household = household ?? HouseholdBootstrapService.bootstrap(context: modelContext)
                    modelContext.insert(me)
                    HapticManager.success()
                } label: {
                    Label("Set up as solo household", systemImage: "person.fill")
                }
            }
        }
    }

    private func addMember() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let member = HouseholdMember(name: trimmed)
        member.household = household ?? HouseholdBootstrapService.bootstrap(context: modelContext)
        modelContext.insert(member)
        newName = ""
        HapticManager.success()
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            let member = members[index]
            guard !member.isCurrentUser else { continue }
            modelContext.delete(member)
        }
    }

    private func inviteFamily() async {
        guard let household else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            let payload = try await cloudService.prepareShare(for: household, context: modelContext)
            sharePayload = SharePayload(share: payload.0, container: payload.1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

private extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let int = UInt64(hex, radix: 16) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
