import SwiftUI
import UserNotifications

// MARK: - Firebase config
let FIREBASE_URL = "https://my-todo-list-b567a-default-rtdb.asia-southeast1.firebasedatabase.app"
let FIREBASE_KEY = "AIzaSyDHKPTvVmsPsnd_em1al9YVzla5dMD56oA"

// MARK: - Task Model
struct Task: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool
    var alarm: String?   // "HH:mm"
    var created: String

    static func == (a: Task, b: Task) -> Bool { a.id == b.id && a.done == b.done && a.text == b.text && a.alarm == b.alarm }
}

// MARK: - Firebase Manager
class FirebaseManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var connected = false
    private var pollTimer: Timer?

    init() { startPolling() }

    func startPolling() {
        fetch()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func fetch() {
        guard let url = URL(string: "\(FIREBASE_URL)/tasks.json?auth=\(FIREBASE_KEY)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, resp, _ in
            guard let self = self, let data = data else { return }
            if let dict = try? JSONDecoder().decode([String: Task].self, from: data) {
                DispatchQueue.main.async {
                    self.tasks = dict.values.sorted { $0.created > $1.created }
                    self.connected = true
                }
            } else {
                DispatchQueue.main.async { self.connected = true }
            }
        }.resume()
    }

    func add(_ task: Task) {
        guard let url = URL(string: "\(FIREBASE_URL)/tasks/\(task.id).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(task)
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.fetch() }
        }.resume()
    }

    func toggle(_ task: Task) {
        guard let url = URL(string: "\(FIREBASE_URL)/tasks/\(task.id)/done.json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(!task.done)
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.fetch() }
        }.resume()
        // Optimistic update
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i].done = !task.done
        }
    }

    func delete(_ task: Task) {
        guard let url = URL(string: "\(FIREBASE_URL)/tasks/\(task.id).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.fetch() }
        }.resume()
        // Optimistic update
        tasks.removeAll { $0.id == task.id }
    }
}

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func schedule(_ task: Task) {
        guard let alarm = task.alarm else { return }
        let parts = alarm.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count == 2 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Task Alarm"
        content.body = task.text
        content.sound = .defaultCritical
        var comps = DateComponents()
        comps.hour = parts[0]
        comps.minute = parts[1]
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: task.id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

// MARK: - App Entry
@main
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}

// MARK: - Main Content
struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "060a0f").ignoresSafeArea()
                HStack(spacing: 12) {
                    // Left: Clock
                    ClockView()
                        .frame(width: geo.size.width * 0.45)
                    // Right: Calendar + Todo
                    VStack(spacing: 12) {
                        CalendarView()
                        TodoView()
                    }
                    .frame(width: geo.size.width * 0.51)
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Clock View
struct ClockView: View {
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var timeStr: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: now)
    }
    var secStr: String {
        let f = DateFormatter(); f.dateFormat = "ss"; return f.string(from: now)
    }
    var dateStr: String {
        let f = DateFormatter(); f.dateFormat = "EEEE · MMMM d, yyyy"; return f.string(from: now).uppercased()
    }
    var secProgress: Double {
        let cal = Calendar.current
        return Double(cal.component(.second, from: now)) / 59.0
    }
    var hours: String { String(timeStr.prefix(2)) }
    var minutes: String { String(timeStr.suffix(2)) }
    @State private var colonVisible = true

    var body: some View {
        PanelView(accent: Color(hex: "00ffc8")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM TIME")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "00ffc8").opacity(0.4))
                    .tracking(3)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(hours)
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.4), radius: 12)
                    Text(":")
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .frame(width: 28, alignment: .center)
                        .opacity(colonVisible ? 1 : 0.05)
                    Text(minutes)
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.4), radius: 12)
                    Text(secStr)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                        .padding(.leading, 8)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 6 }
                }

                // Seconds bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: "00aaff"), Color(hex: "00ffc8")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * secProgress, height: 3)
                            .animation(.linear(duration: 1), value: secProgress)
                    }
                }
                .frame(height: 3)

                Text(dateStr)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .onReceive(timer) { t in
            now = t
            let s = Calendar.current.component(.second, from: t)
            withAnimation(.none) { colonVisible = s % 2 == 0 }
        }
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @State private var display = Date()
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dayNames = ["Su","Mo","Tu","We","Th","Fr","Sa"]

    var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: display).uppercased()
    }

    var days: [(Int, Bool, Bool)] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year,.month], from: display))!
        let wd = cal.component(.weekday, from: start) - 1
        let dim = cal.range(of: .day, in: .month, for: display)!.count
        let dip = cal.range(of: .day, in: .month, for: cal.date(byAdding: .month, value: -1, to: display)!)!.count
        let today = Date()
        let tm = cal.component(.month, from: today), ty = cal.component(.year, from: today), td = cal.component(.day, from: today)
        let cm = cal.component(.month, from: display), cy = cal.component(.year, from: display)
        var result: [(Int,Bool,Bool)] = []
        for i in 0..<wd { result.append((dip-wd+1+i, false, false)) }
        for d in 1...dim { result.append((d, true, d==td && cm==tm && cy==ty)) }
        var nx = 1; while result.count < 42 { result.append((nx, false, false)); nx += 1 }
        return result
    }

    var body: some View {
        PanelView(accent: Color(hex: "00aaff")) {
            VStack(spacing: 6) {
                HStack {
                    Text(monthLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                        .tracking(0.5)
                    Spacer()
                    HStack(spacing: 4) {
                        Button { display = Calendar.current.date(byAdding: .month, value: -1, to: display)! } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 24, height: 24)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                        Button { display = Calendar.current.date(byAdding: .month, value: 1, to: display)! } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 24, height: 24)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                LazyVGrid(columns: cols, spacing: 2) {
                    ForEach(dayNames, id: \.self) { d in
                        Text(d).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.3))
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        ZStack {
                            if day.2 { Circle().fill(Color(hex: "00ffc8")).frame(width: 22, height: 22) }
                            Text("\(day.0)")
                                .font(.system(size: 10, weight: day.2 ? .bold : .regular))
                                .foregroundColor(day.2 ? Color(hex: "060a0f") : day.1 ? .white.opacity(0.55) : .white.opacity(0.15))
                        }
                        .frame(maxWidth: .infinity, minHeight: 22)
                    }
                }
            }
        }
    }
}

// MARK: - Todo View
struct TodoView: View {
    @StateObject private var firebase = FirebaseManager()
    @State private var newText = ""
    @State private var showAlarmPicker = false
    @State private var pendingAlarm: Date = Date()
    @State private var hasAlarm = false
    @State private var filterMode = "all"

    var filtered: [Task] {
        firebase.tasks.filter { t in
            switch filterMode {
            case "pending": return !t.done
            case "done": return t.done
            case "alarm": return t.alarm != nil
            default: return true
            }
        }
    }

    var pending: Int { firebase.tasks.filter { !$0.done }.count }

    var body: some View {
        PanelView(accent: Color(hex: "00ffc8")) {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("TASKS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .tracking(2)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(firebase.connected ? Color(hex: "00ffc8") : .gray)
                            .frame(width: 6, height: 6)
                        Text(firebase.connected ? "Live" : "Offline")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Text(pending == 0 ? "All done!" : "\(pending) left")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.leading, 6)
                }

                // Filter tabs
                HStack(spacing: 5) {
                    ForEach([("all","All"),("pending","Pending"),("done","Done"),("alarm","Alarm")], id: \.0) { key, label in
                        Button { filterMode = key } label: {
                            Text(label)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(filterMode == key ? Color(hex: "060a0f") : .white.opacity(0.4))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(filterMode == key ? Color(hex: "00ffc8") : Color.white.opacity(0.05))
                                .cornerRadius(5)
                        }
                    }
                    Spacer()
                }

                // Input row
                HStack(spacing: 6) {
                    TextField("Add task...", text: $newText)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "00ffc8").opacity(0.2), lineWidth: 1))
                        .onSubmit { addTask() }

                    Button { showAlarmPicker.toggle() } label: {
                        Text(hasAlarm ? formatTime(pendingAlarm) : "Alarm")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "00aaff"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(hasAlarm ? Color(hex: "00aaff").opacity(0.2) : Color(hex: "00aaff").opacity(0.08))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "00aaff").opacity(hasAlarm ? 0.6 : 0.2), lineWidth: 1))
                    }

                    Button(action: addTask) {
                        Text("ADD")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "060a0f"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(hex: "00ffc8"))
                            .cornerRadius(8)
                    }
                }

                // Alarm picker
                if showAlarmPicker {
                    VStack(spacing: 6) {
                        DatePicker("Alarm time", selection: $pendingAlarm, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxHeight: 100)
                            .clipped()
                            .colorScheme(.dark)
                        HStack(spacing: 8) {
                            Button { hasAlarm = false; showAlarmPicker = false } label: {
                                Text("No Alarm")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(7)
                            }
                            Button { hasAlarm = true; showAlarmPicker = false } label: {
                                Text("Set \(formatTime(pendingAlarm))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "00ffc8"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "00ffc8").opacity(0.12))
                                    .cornerRadius(7)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }

                // Task list
                ScrollView {
                    LazyVStack(spacing: 5) {
                        if filtered.isEmpty {
                            Text("No tasks")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.2))
                                .padding(.top, 12)
                        }
                        ForEach(filtered) { task in
                            TaskRowView(task: task,
                                onToggle: { firebase.toggle(task) },
                                onDelete: {
                                    NotificationManager.shared.cancel(task.id)
                                    firebase.delete(task)
                                })
                        }
                    }
                }
            }
        }
    }

    func addTask() {
        let txt = newText.trimmingCharacters(in: .whitespaces)
        guard !txt.isEmpty else { return }
        let id = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let alarmStr = hasAlarm ? formatTime(pendingAlarm) : nil
        let task = Task(id: id, text: txt, done: false, alarm: alarmStr, created: ISO8601DateFormatter().string(from: Date()))
        firebase.add(task)
        if let alarm = alarmStr { _ = alarm; NotificationManager.shared.schedule(task) }
        newText = ""
        hasAlarm = false
        showAlarmPicker = false
    }

    func formatTime(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - Task Row
struct TaskRowView: View {
    let task: Task
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                ZStack {
                    Circle().strokeBorder(Color(hex: "00ffc8").opacity(0.35), lineWidth: 1.5).frame(width: 20, height: 20)
                    if task.done {
                        Circle().fill(Color(hex: "00ffc8").opacity(0.2)).frame(width: 20, height: 20)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "00ffc8"))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.text)
                    .font(.system(size: 12))
                    .foregroundColor(task.done ? .white.opacity(0.3) : .white.opacity(0.85))
                    .strikethrough(task.done, color: .white.opacity(0.3))
                    .lineLimit(2)
                if let alarm = task.alarm {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.fill").font(.system(size: 8)).foregroundColor(Color(hex: "00aaff"))
                        Text(alarm).font(.system(size: 10, design: .monospaced)).foregroundColor(Color(hex: "00aaff"))
                    }
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .medium)).foregroundColor(.red.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .opacity(task.done ? 0.5 : 1)
    }
}

// MARK: - Panel View
struct PanelView<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.18), lineWidth: 1))
            GeometryReader { g in
                LinearGradient(colors: [.clear, accent, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.7, height: 1)
                    .position(x: g.size.width / 2, y: 0)
                    .opacity(0.5)
            }
            content().padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
