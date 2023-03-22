import CoreData
import SwiftUI
import Swinject

extension AddTempTarget {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var isPromtPresented = false
        @State private var isRemoveAlertPresented = false
        @State private var removeAlert: Alert?
        @State private var isEditing = false

        @FetchRequest(
            entity: ViewPercentage.entity(),
            sortDescriptors: [NSSortDescriptor(key: "enabled", ascending: false)]
        ) var isEnabledArray: FetchedResults<ViewPercentage>

        @Environment(\.managedObjectContext) var moc

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            var minSlider: Decimal = 15
            var maxSlider: Decimal = (state.maxValue * 100)
            Form {
                if !state.presets.isEmpty {
                    Section(header: Text("Presets")) {
                        ForEach(state.presets) { preset in
                            presetView(for: preset)
                        }
                    }
                }

                Toggle(isOn: $state.viewPercentage) {
                    Text("Exercise / Pre Meal Slider")
                }

                if state.viewPercentage {
                    Section(
                        header: Text("TT Effect on Basal and Sensitivity"),
                        footer: Text(
                            NSLocalizedString(
                                "Setting of Half Basal Target (HBT) adjusts how a TempTargets affect Basal and ISF.\nA lower HBT will allow Basal to be reduced earlier (at a less high TT).\n",
                                comment: ""
                            ) +
                                NSLocalizedString("Current HBT setting in Prefs: ", comment: "") + "\(state.halfBasal) " +
                                NSLocalizedString(
                                    "mg/dl.\nAutosens.max setting determines the max endpoint for Sensitivity Ratio, how far the LowTTlowersSensitivity can raise your Insulin Ratio.",
                                    comment: ""
                                ) +
                                " (\(state.maxValue): \(state.maxValue * 100) %)"
                        )
                    ) {
                        VStack {
                            HStack {
                                Text(NSLocalizedString("Target", comment: ""))
                                Spacer()
                                DecimalTextField(
                                    "0",
                                    value: $state.low,
                                    formatter: formatter,
                                    cleanInput: true
                                )
                                Text(state.units.rawValue).foregroundColor(.secondary)
                            }
                            Text(NSLocalizedString("Desired Insulin Ratio / Override", comment: ""))

                            // if state.low < 100 { minSlider = 100 } // throws an error on the Form
                            // if state.low > 100 { maxSlider = 100 }
                            Slider(
                                value: $state.percentage,
                                in: Double(minSlider) ... Double(maxSlider),
                                step: 5
                            ) {}
                            minimumValueLabel: { Text("\(Double(minSlider), specifier: "%.0f")%") }
                            maximumValueLabel: { Text("\(Double(maxSlider), specifier: "%.0f")%") }
                            onEditingChanged: { editing in
                                isEditing = editing
                            }

                            Text("\(state.percentage.formatted(.number)) %")
                                .foregroundColor(isEditing ? .orange : .blue)
                                .font(.largeTitle)
                            Divider()
                            HStack {
                                Text(
                                    NSLocalizedString("Half Basal Target should be: ", comment: "")
                                )
                                .foregroundColor(.primary).italic()
                                Text("\(computeHBT().formatted(.number)) mg/dL!").fixedSize(horizontal: true, vertical: false)
                            }
                            Divider()
                            Text(
                                NSLocalizedString(
                                    "Please enter the above HBT in Preferences to initiate the desired Insulin Ratio.\nIf you don't the set Target will put you at Insulin Ratio of ",
                                    comment: ""
                                ) + "\(computeRatio().formatted(.number)) % as HBT is currently \(state.halfBasal) mg/dL."
                            )
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    Section(header: Text("Custom")) {
                        HStack {
                            Text("Target")
                            Spacer()
                            DecimalTextField("0", value: $state.low, formatter: formatter, cleanInput: true)
                            Text(state.units.rawValue).foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Duration")
                            Spacer()
                            DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                            Text("minutes").foregroundColor(.secondary)
                        }
                        DatePicker("Date", selection: $state.date)
                        Button { isPromtPresented = true }
                        label: { Text("Save as preset") }
                    }
                }
                if state.viewPercentage {
                    Section {
                        HStack {
                            Text("Duration")
                            Spacer()
                            DecimalTextField("0", value: $state.duration, formatter: formatter, cleanInput: true)
                            Text("minutes").foregroundColor(.secondary)
                        }
                        DatePicker("Date", selection: $state.date)
                        Button { isPromtPresented = true }
                        label: { Text("Save as preset") }
                    }
                }

                Section {
                    Button { state.enact() }
                    label: { Text("Enact") }
                    Button { state.cancel() }
                    label: { Text("Cancel Temp Target") }
                }
            }
            .popover(isPresented: $isPromtPresented) {
                Form {
                    Section(header: Text("Enter preset name")) {
                        TextField("Name", text: $state.newPresetName)
                        Button {
                            state.save()
                            isPromtPresented = false
                        }
                        label: { Text("Save") }
                        Button { isPromtPresented = false }
                        label: { Text("Cancel") }
                    }
                }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Enact Temp Target")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
            .onDisappear {
                if state.viewPercentage {
                    let isEnabledMoc = ViewPercentage(context: moc)
                    isEnabledMoc.enabled = true
                    isEnabledMoc.date = Date()
                    try? moc.save()
                } else {
                    let isEnabledMoc = ViewPercentage(context: moc)
                    isEnabledMoc.enabled = false
                    isEnabledMoc.date = Date()
                    try? moc.save()
                }
            }
        }

        func computeTarget() -> Decimal {
            var ratio = Decimal(state.percentage / 100)
            let hB = state.halfBasal
            let c = hB - 100
            var target = (c / ratio) - c + 100

            if c * (c + target - 100) <= 0 {
                ratio = state.maxValue
                target = (c / ratio) - c + 100
            }
            return target
        }

        func computeRatio() -> Decimal {
            let hbt = state.halfBasal
            let normalTarget: Decimal = 100
            var target: Decimal = state.low
            if state.units == .mmolL { target = target / 0.0555 }
            var ratio = state.maxValue
            if (target + hbt - (2 * normalTarget)) !=
                0.0 { ratio = (hbt - normalTarget) / (target + hbt - (2 * normalTarget)) } // prevent division by 0
            if ratio < 0 { ratio = state.maxValue } // if negative Value take max Ratio
            ratio = Decimal(round(Double(min(ratio, state.maxValue) * 100)))
            return ratio
        }

        func computeHBT() -> Decimal {
            var ratio = Decimal(state.percentage / 100)
            let normalTarget: Decimal = 100
            var target: Decimal = state.low
            if state.units == .mmolL { target = target / 0.0555 }
            var hbt: Decimal = state.halfBasal
            if ratio != 1 {
                hbt = ((2 * ratio * normalTarget) - normalTarget - (ratio * target)) / (ratio - 1)
            }
            hbt = Decimal(round(Double(hbt)))
            // state.halfBasal = hbt
            return hbt
        }

        private func presetView(for preset: TempTarget) -> some View {
            var low = preset.targetBottom
            var high = preset.targetTop
            if state.units == .mmolL {
                low = low?.asMmolL
                high = high?.asMmolL
            }
            return HStack {
                VStack {
                    HStack {
                        Text(preset.displayName)
                        Spacer()
                    }
                    HStack(spacing: 2) {
                        Text(
                            "\(formatter.string(from: (low ?? 0) as NSNumber)!) - \(formatter.string(from: (high ?? 0) as NSNumber)!)"
                        )
                        .foregroundColor(.secondary)
                        .font(.caption)

                        Text(state.units.rawValue)
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("for")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(formatter.string(from: preset.duration as NSNumber)!)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("min")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Spacer()
                    }.padding(.top, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    state.enactPreset(id: preset.id)
                }

                Image(systemName: "xmark.circle").foregroundColor(.secondary)
                    .contentShape(Rectangle())
                    .padding(.vertical)
                    .onTapGesture {
                        removeAlert = Alert(
                            title: Text("Are you sure?"),
                            message: Text("Delete preset \"\(preset.displayName)\""),
                            primaryButton: .destructive(Text("Delete"), action: { state.removePreset(id: preset.id) }),
                            secondaryButton: .cancel()
                        )
                        isRemoveAlertPresented = true
                    }
                    .alert(isPresented: $isRemoveAlertPresented) {
                        removeAlert!
                    }
            }
        }
    }
}
