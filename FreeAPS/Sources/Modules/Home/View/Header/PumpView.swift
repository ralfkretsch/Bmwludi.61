import SwiftUI

struct PumpView: View {
    @Binding var reservoir: Decimal?
    @Binding var battery: Battery?
    @Binding var name: String
    @Binding var expiresAtDate: Date?
    @Binding var timerDate: Date

    @State var state: Home.StateModel

    @Environment(\.colorScheme) var colorScheme

    private var reservoirFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private var batteryFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        return dateFormatter
    }

    var body: some View {
        HStack(spacing: 10) {
            if let date = expiresAtDate {
                HStack(spacing: 0) {
                    Image("pod_reservoir")
                        .resizable(resizingMode: .stretch)
                        .frame(width: IAPSconfig.iconSize * 1.15, height: IAPSconfig.iconSize * 1.6)
                        .foregroundColor(colorScheme == .dark ? .secondary : .white)
                    let timeLeft = date.timeIntervalSince(timerDate)
                    remainingTime(time: date.timeIntervalSince(timerDate))
                        .font(.statusFont).fontWeight(.bold).foregroundStyle(timeLeft < 4 * 60 * 60 ? .red : .secondary)
                        .foregroundColor(timeLeft < 4 * 60 * 60 ? .red : colorScheme == .dark ? .white : .black)
                }
            } else if let battery = battery, expiresAtDate == nil {
                let percent = (battery.percent ?? 100) > 80 ? 100 : (battery.percent ?? 100) < 81 &&
                    (battery.percent ?? 100) >
                    60 ? 75 : (battery.percent ?? 100) < 61 && (battery.percent ?? 100) > 40 ? 50 : 25
                Image(systemName: "battery.\(percent)")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 15)
                    .foregroundColor(batteryColor)
            }

            if let reservoir = reservoir {
                let fill = CGFloat(min(max(Double(reservoir) / 200.0, 0.15), Double(reservoir) / 200.0, 0.9)) * 12
                HStack {
                    Image("vial")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 10)
                        .foregroundColor(reservoirColor)
                        .overlay {
                            UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 2, bottomTrailing: 2))
                                .fill(Color.insulin)
                                .frame(maxWidth: 9, maxHeight: fill)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    if reservoir == 0xDEAD_BEEF {
                        HStack(spacing: 0) {
                            Text("50+ ").font(.statusFont).bold()
                            Text(NSLocalizedString("U", comment: "Insulin unit")).font(.statusFont).foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 0) {
                            Text(
                                reservoirFormatter
                                    .string(from: reservoir as NSNumber)!
                            ).font(.statusFont).bold()
                            Text(NSLocalizedString(" U", comment: "Insulin unit")).font(.statusFont).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No Pump").font(.statusFont).foregroundStyle(.secondary)
            }
        }
    }

    private func remainingTime(time: TimeInterval) -> some View {
        VStack {
            if time > 0 {
                let days = Int(time / 1.days.timeInterval)
                let hours = Int(time / 1.hours.timeInterval)
                let minutes = Int(time / 1.minutes.timeInterval)
                if days >= 1 {
                    Text("\(days)" + NSLocalizedString("d", comment: "abbreviation for days"))
                    Text(" \(hours - days * 24)" + NSLocalizedString("h", comment: "abbreviation for hours"))
                } else if hours >= 1 {
                    Text("\(hours)" + NSLocalizedString("h", comment: "abbreviation for hours"))
                } else {
                    Text("\(minutes)" + NSLocalizedString("m", comment: "abbreviation for minutes"))
                }
            } else {
                Text(NSLocalizedString("Replace", comment: "View/Header when pod expired"))
            }
        }
    }

    private var batteryColor: Color {
        guard let battery = battery, let percent = battery.percent else {
            return .gray
        }

        switch percent {
        case ...10:
            return .red
        case ...20:
            return .yellow
        default:
            return .green
        }
    }

    private var reservoirColor: Color {
        guard let reservoir = reservoir else {
            return .gray
        }

        switch reservoir {
        case ...10:
            return .red
        case ...30:
            return .yellow
        default:
            return .blue
        }
    }

    private var timerColor: Color {
        guard let expisesAt = expiresAtDate else {
            return .gray
        }

        let time = expisesAt.timeIntervalSince(timerDate)

        switch time {
        case ...8.hours.timeInterval:
            return .red
        case ...1.days.timeInterval:
            return .yellow
        default:
            return .green
        }
    }
}

struct Hairline: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: UIScreen.main.bounds.width / 1.3, height: 1)
            .opacity(0.5)
    }
}
