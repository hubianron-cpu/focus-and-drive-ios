import SwiftUI
import FamilyControls

struct HomeView: View {
    @ObservedObject var model: DrivingViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPicker = false
    @State private var pickerSelection = FamilyActivitySelection()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Focus & Drive")
                    .font(.largeTitle.weight(.semibold))
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityAddTraits(.isHeader)
                Text("פחות הסחות דעת. יותר תשומת לב לדרך.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    Label(model.statusTitle,
                          systemImage: model.isDriving ? "car.fill" : "car")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(model.isDriving ? Color.green : Color.primary)
                    Text(model.statusDetail)
                        .foregroundStyle(.secondary)
                    Button {
                        if model.isDriving { model.endDriving() } else { model.startDriving() }
                    } label: {
                        Text(model.isDriving ? "סיום נהיגה" : "התחלת נהיגה")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.green.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                            .foregroundStyle(.black)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isDriving && (model.authorization != .approved || !model.hasValidSelection || model.isRequesting))
                    .accessibilityHint("יש לבצע שינויים רק כשחונים בבטחה")
                }
                .padding(24)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24))

                if !model.isDriving {
                    if model.authorization != .approved {
                        Button(model.isRequesting ? "ממתינים להרשאה…" : "מתן הרשאת זמן מסך") {
                            Task { await model.requestAuthorization() }
                        }
                        .disabled(model.isRequesting)
                        Text("ללא אישור לא ניתן להגביל יישומים.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Button("בחירת יישומים להגבלה") {
                            pickerSelection = model.selection
                            showingPicker = true
                        }
                        Text("בחרו את WhatsApp בלבד לבדיקה הראשונה. השאירו את Waze ואת הטלפון מחוץ לבחירה. ניתן לבחור עד 50 יישומים. קטגוריות ואתרים אינם נתמכים בגרסה זו.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("יישומים שנבחרו: \(model.selection.applicationTokens.count)")
                            .font(.footnote)
                    }
                }
                if let message = model.message {
                    Text(message).foregroundStyle(.orange).accessibilityLabel(message)
                }
                Label("יש להפעיל, לסיים או לשנות הגדרות רק כשחונים בבטחה.", systemImage: "parkingsign.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.045).ignoresSafeArea())
        .tint(.green)
        .familyActivityPicker(isPresented: $showingPicker, selection: $pickerSelection)
        .onChange(of: showingPicker) { presented in
            if !presented { model.saveSelection(pickerSelection) }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.reconcile() }
        }
        .onChange(of: model.authorization) { status in
            if status != .approved {
                pickerSelection = FamilyActivitySelection()
                showingPicker = false
            }
        }
    }
}
