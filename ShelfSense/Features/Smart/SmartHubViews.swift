//
//  SmartHubViews.swift
//  ShelfSense
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation

struct RestockPredictionsView: View {
    @Query private var inventory: [InventoryItem]
    @Query private var receipts: [Receipt]
    @Query private var lineItems: [ReceiptLineItem]

    private var predictions: [RestockPrediction] {
        RestockPredictionService.predictions(from: inventory, receipts: receipts, lineItems: lineItems)
    }

    var body: some View {
        List {
            if predictions.isEmpty {
                ContentUnavailableView("All stocked up", systemImage: "checkmark.circle", description: Text("No restock needed soon"))
            } else {
                ForEach(predictions) { prediction in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prediction.itemName).font(.shelfSubheadline)
                        Text("Restock by \(prediction.suggestedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.shelfCaption).foregroundStyle(ShelfTheme.copperLight)
                        Text(prediction.confidence).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        if let interval = prediction.averageDaysBetweenPurchases {
                            Text("Usually buy every ~\(interval) days").font(.system(size: 10)).foregroundStyle(ShelfTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Restock Predictions")
    }
}

struct WasteTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WasteEntry.loggedAt, order: .reverse) private var entries: [WasteEntry]
    @State private var showAdd = false

    private var totalWaste: Double {
        entries.compactMap(\.estimatedValue).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Total waste logged", value: Formatters.currencyString(totalWaste))
                LabeledContent("Entries", value: "\(entries.count)")
            }

            Button { showAdd = true } label: {
                Label("Log wasted item", systemImage: "plus.circle.fill")
            }

            ForEach(entries, id: \.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.itemName).font(.shelfSubheadline)
                    Text(entry.loggedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                    if let value = entry.estimatedValue {
                        Text(Formatters.currencyString(value)).font(.shelfCaption).foregroundStyle(ShelfTheme.warning)
                    }
                }
            }
            .onDelete { offsets in offsets.forEach { modelContext.delete(entries[$0]) } }
        }
        .navigationTitle("Waste Tracker")
        .sheet(isPresented: $showAdd) { AddWasteSheet() }
    }
}

struct AddWasteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $name)
                TextField("Estimated value", text: $value).keyboardType(.decimalPad)
            }
            .navigationTitle("Log Waste")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(WasteEntry(itemName: name, estimatedValue: Double(value)))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct SubstitutionView: View {
    @State private var query = "butter"

    private var results: [Substitution] {
        SubstitutionService.substitutes(for: query)
    }

    var body: some View {
        List {
            Section {
                TextField("Ingredient", text: $query)
            }

            Section("Common Items") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SubstitutionService.commonItems(), id: \.self) { item in
                            Button(item) { query = item }
                                .font(.shelfCaption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(query == item ? ShelfTheme.copper.opacity(0.3) : ShelfTheme.backgroundSecondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if results.isEmpty {
                ContentUnavailableView("No substitutes found", systemImage: "arrow.triangle.swap")
            } else {
                ForEach(results) { sub in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sub.substitute).font(.shelfSubheadline).foregroundStyle(ShelfTheme.copperLight)
                        Text(sub.reason).font(.shelfCaption).foregroundStyle(ShelfTheme.textSecondary)
                        Text("Ratio: \(sub.ratio)").font(.system(size: 10)).foregroundStyle(ShelfTheme.textTertiary)
                    }
                }
            }
        }
        .navigationTitle("Substitutions")
    }
}

struct UnitConverterView: View {
    @State private var value = "1"
    @State private var fromUnit = "cup"
    @State private var toUnit = "ml"

    private var result: String? {
        guard let num = Double(value) else { return nil }
        return UnitConversionService.formatConversion(value: num, from: fromUnit, to: toUnit)
    }

    var body: some View {
        Form {
            TextField("Amount", text: $value).keyboardType(.decimalPad)
            Picker("From", selection: $fromUnit) {
                ForEach(UnitConversionService.volumeUnits + UnitConversionService.weightUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
            Picker("To", selection: $toUnit) {
                ForEach(UnitConversionService.volumeUnits + UnitConversionService.weightUnits, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
            if let result {
                Section("Result") { Text(result).foregroundStyle(ShelfTheme.copperLight) }
            }
        }
        .navigationTitle("Unit Converter")
    }
}

struct VoiceAddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var transcript = ""
    @State private var isListening = false
    @State private var addedItems: [String] = []

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isListening ? "mic.fill" : "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(isListening ? ShelfTheme.copper : ShelfTheme.textTertiary)
                .symbolEffect(.pulse, isActive: isListening)

            Text(transcript.isEmpty ? "Tap to speak items" : transcript)
                .font(.shelfSubheadline)
                .foregroundStyle(ShelfTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(isListening ? "Stop" : "Start Listening") {
                toggleListening()
            }
            .font(.shelfHeadline)
            .padding()
            .background(ShelfTheme.copper.opacity(0.2))
            .foregroundStyle(ShelfTheme.copperLight)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if !addedItems.isEmpty {
                VStack(alignment: .leading) {
                    Text("Added to list:").font(.shelfCaption)
                    ForEach(addedItems, id: \.self) { Text("• \($0)").font(.shelfSubheadline) }
                }
            }

            Spacer()
        }
        .padding()
        .background(ShelfGradientBackground())
        .navigationTitle("Voice Add")
    }

    private func toggleListening() {
        if isListening {
            isListening = false
            parseAndAdd(transcript)
        } else {
            requestSpeechAndListen()
        }
    }

    private func requestSpeechAndListen() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async { startRecognition() }
        }
    }

    private func startRecognition() {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return }
        isListening = true
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        try? audioEngine.start()

        recognizer.recognitionTask(with: request) { result, _ in
            if let result {
                DispatchQueue.main.async { transcript = result.bestTranscription.formattedString }
            }
        }
    }

    private func parseAndAdd(_ text: String) {
        let separators = CharacterSet(charactersIn: ", and &")
        let items = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 2 }

        for name in items {
            modelContext.insert(ShoppingListItem(name: name, reason: "Voice added"))
            addedItems.append(name)
        }
        if !items.isEmpty { HapticManager.success() }
    }
}
