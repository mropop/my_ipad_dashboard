import SwiftUI
import AudioToolbox
import AVFoundation

// MARK: - Config
let FIREBASE_URL = "https://my-todo-list-b567a-default-rtdb.asia-southeast1.firebasedatabase.app"

// MARK: - Task Model
struct Task: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool
    var alarm: String?
    var created: String
}

// MARK: - Firebase Manager (reliable polling)
class FirebaseManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var connected = false
    private var timer: Timer?

    init() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.fetch()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func fetch() {
        guard let url = URL(string: "\(FIREBASE_URL)/tasks.json") else { return }
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if err != nil {
                    self.connected = false
                    return
                }
                self.connected = true
                guard let data = data,
                      let str = String(data: data, encoding: .utf8),
                      str != "null" else {
                    self.tasks = []
                    return
                }
                guard let dict = try? JSONDecoder().decode([String: Task].self, from: data) else { return }
                let sorted = dict.values.sorted { $0.created > $1.created }
                self.tasks = sorted
                AlarmManager.shared.rescheduleAll(sorted)
            }
        }.resume()
    }

    func add(_ task: Task) {
        // Optimistic
        tasks.insert(task, at: 0)
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
        // Optimistic
        if let i = tasks.firstIndex(where: { $0.id == task.id }) { tasks[i].done = !task.done }
        guard let url = URL(string: "\(FIREBASE_URL)/tasks/\(task.id)/done.json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(!task.done)
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.fetch() }
        }.resume()
    }

    func delete(_ task: Task) {
        // Optimistic
        tasks.removeAll { $0.id == task.id }
        guard let url = URL(string: "\(FIREBASE_URL)/tasks/\(task.id).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.fetch() }
        }.resume()
    }
}

// MARK: - Alarm Manager
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    @Published var firingAlarm: Task? = nil
    private var timers: [String: Timer] = [:]
    var audioPlayer: AVAudioPlayer?  // keep reference alive

    func schedule(_ task: Task) {
        guard let alarm = task.alarm, !task.done else { return }
        cancel(task.id)
        let parts = alarm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let now = Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = parts[0]
        comps.minute = parts[1]
        comps.second = 0
        guard var fireDate = Calendar.current.date(from: comps) else { return }
        if fireDate <= now {
            fireDate = Calendar.current.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        let interval = fireDate.timeIntervalSince(now)
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.fire(task)
        }
        RunLoop.main.add(t, forMode: .common)
        timers[task.id] = t
    }

    func fire(_ task: Task) {
        timers.removeValue(forKey: task.id)
        DispatchQueue.main.async {
            self.firingAlarm = task
            self.playAlarm()
        }
    }

    func cancel(_ id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    func cancelAll() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }

    func rescheduleAll(_ tasks: [Task]) {
        // Cancel old, reschedule active ones
        let active = tasks.filter { !$0.done && $0.alarm != nil }
        let activeIds = Set(active.map { $0.id })
        // Cancel removed tasks
        for id in timers.keys where !activeIds.contains(id) { cancel(id) }
        // Schedule new ones
        active.forEach { schedule($0) }
    }

    func playAlarm() {
        // Set audio session to playback — bypasses silent/ring switch
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session: \(error)") }

        // Use system sound file directly — simplest and most reliable
        // /System/Library/Audio/UISounds/ contains many built-in sounds
        let soundPaths = [
            "/System/Library/Audio/UISounds/alarm.caf",
            "/System/Library/Audio/UISounds/begin_record.caf",
            "/System/Library/Audio/UISounds/low_power.caf",
            "/System/Library/Audio/UISounds/payment_success.caf",
        ]

        // Try each path until one works
        var player: AVAudioPlayer?
        for path in soundPaths {
            let url = URL(fileURLWithPath: path)
            if let p = try? AVAudioPlayer(contentsOf: url) {
                player = p
                break
            }
        }

        if let player = player {
            player.numberOfLoops = 3  // play 4 times total
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            // Keep reference alive
            self.audioPlayer = player
        } else {
            // Fallback — system sound IDs
            // 1304 = tweet, 1016 = payment success, 1033 = begin_record
            AudioServicesPlaySystemSound(1304)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { AudioServicesPlaySystemSound(1304) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { AudioServicesPlaySystemSound(1304) }
        }

        // Vibrate
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
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
                }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var alarmMgr = AlarmManager.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "060a0f").ignoresSafeArea()

                HStack(spacing: 12) {
                    ClockView()
                        .frame(width: geo.size.width * 0.45)
                    VStack(spacing: 12) {
                        CalendarView()
                        TodoView()
                    }
                    .frame(width: geo.size.width * 0.51)
                }
                .padding(12)

                // Alarm popup
                if let alarm = alarmMgr.firingAlarm {
                    AlarmPopupView(task: alarm) {
                        alarmMgr.firingAlarm = nil
                    }
                }
            }
        }
    }
}

// MARK: - Clock
struct ClockView: View {
    @State private var now = Date()
    @State private var colonOn = true
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var h: String { String(format: "%02d", Calendar.current.component(.hour, from: now)) }
    var m: String { String(format: "%02d", Calendar.current.component(.minute, from: now)) }
    var s: String { String(format: "%02d", Calendar.current.component(.second, from: now)) }
    var secProg: Double { Double(Calendar.current.component(.second, from: now)) / 59.0 }
    var dateStr: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMMM d, yyyy"
        return f.string(from: now).uppercased()
    }

    var body: some View {
        PanelView(accent: Color(hex: "00ffc8")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM TIME")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "00ffc8").opacity(0.4))
                    .tracking(3)

                // Time
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(h)
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.4), radius: 14)
                    Text(":")
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .frame(width: 28, alignment: .center)
                        .opacity(colonOn ? 1 : 0.05)
                    Text(m)
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.4), radius: 14)
                    Text(s)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                        .shadow(color: Color(hex: "00aaff").opacity(0.3), radius: 8)
                        .padding(.leading, 8)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 6 }
                }

                // Seconds bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "00aaff"), Color(hex: "00ffc8")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: g.size.width * secProg, height: 3)
                            .animation(.linear(duration: 1), value: secProg)
                    }
                }
                .frame(height: 3)

                Text(dateStr)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .onReceive(timer) { t in
            now = t
            colonOn = Calendar.current.component(.second, from: t) % 2 == 0
        }
    }
}

// MARK: - Calendar
struct CalendarView: View {
    @State private var display = Date()
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dn = ["Su","Mo","Tu","We","Th","Fr","Sa"]

    var label: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: display).uppercased()
    }

    var days: [(Int, Bool, Bool)] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year,.month], from: display))!
        let wd = cal.component(.weekday, from: start) - 1
        let dim = cal.range(of: .day, in: .month, for: display)!.count
        let dip = cal.range(of: .day, in: .month, for: cal.date(byAdding: .month, value: -1, to: display)!)!.count
        let td = cal.component(.day, from: Date())
        let tm = cal.component(.month, from: Date())
        let ty = cal.component(.year, from: Date())
        let cm = cal.component(.month, from: display)
        let cy = cal.component(.year, from: display)
        var r: [(Int,Bool,Bool)] = []
        for i in 0..<wd { r.append((dip-wd+1+i, false, false)) }
        for d in 1...dim { r.append((d, true, d==td && cm==tm && cy==ty)) }
        var nx = 1; while r.count < 42 { r.append((nx, false, false)); nx += 1 }
        return r
    }

    var body: some View {
        PanelView(accent: Color(hex: "00aaff")) {
            VStack(spacing: 6) {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                    Spacer()
                    HStack(spacing: 4) {
                        Button { display = Calendar.current.date(byAdding: .month, value: -1, to: display)! } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                        Button { display = Calendar.current.date(byAdding: .month, value: 1, to: display)! } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                LazyVGrid(columns: cols, spacing: 2) {
                    ForEach(dn, id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        ZStack {
                            if day.2 {
                                Circle().fill(Color(hex: "00ffc8")).frame(width: 22, height: 22)
                            }
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

// MARK: - Todo
struct TodoView: View {
    @StateObject private var fb = FirebaseManager()
    @State private var newText = ""
    @State private var hasAlarm = false
    @State private var pendingAlarm = Date()
    @State private var showPicker = false
    @State private var filterMode = "all"

    var filtered: [Task] {
        fb.tasks.filter {
            switch filterMode {
            case "pending": return !$0.done
            case "done": return $0.done
            case "alarm": return $0.alarm != nil
            default: return true
            }
        }
    }

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
                            .fill(fb.connected ? Color(hex: "00ffc8") : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(fb.connected ? "Live" : "Offline")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    let pending = fb.tasks.filter { !$0.done }.count
                    Text(pending == 0 ? "All done!" : "\(pending) left")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.leading, 6)
                }

                // Filter tabs
                HStack(spacing: 4) {
                    ForEach([("all","All"),("pending","Pending"),("done","Done"),("alarm","Alarm")], id: \.0) { k, l in
                        Button { filterMode = k } label: {
                            Text(l)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(filterMode == k ? Color(hex: "060a0f") : .white.opacity(0.4))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(filterMode == k ? Color(hex: "00ffc8") : Color.white.opacity(0.05))
                                .cornerRadius(5)
                        }
                    }
                    Spacer()
                }

                // Input
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

                    Button { showPicker.toggle() } label: {
                        Text(hasAlarm ? fmt(pendingAlarm) : "Alarm")
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
                if showPicker {
                    VStack(spacing: 6) {
                        DatePicker("", selection: $pendingAlarm, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxHeight: 100)
                            .clipped()
                            .colorScheme(.dark)
                        HStack(spacing: 8) {
                            Button { hasAlarm = false; showPicker = false } label: {
                                Text("No Alarm")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    .background(Color.red.opacity(0.08)).cornerRadius(7)
                            }
                            Button { hasAlarm = true; showPicker = false } label: {
                                Text("Set \(fmt(pendingAlarm))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "00ffc8"))
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    .background(Color(hex: "00ffc8").opacity(0.12)).cornerRadius(7)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }

                // List
                ScrollView {
                    LazyVStack(spacing: 5) {
                        if filtered.isEmpty {
                            Text(fb.tasks.isEmpty ? "No tasks yet" : "No tasks in this filter")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.2))
                                .padding(.top, 12)
                        }
                        ForEach(filtered) { task in
                            TaskRow(task: task,
                                onToggle: { fb.toggle(task) },
                                onDelete: { AlarmManager.shared.cancel(task.id); fb.delete(task) })
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
        let alarmStr = hasAlarm ? fmt(pendingAlarm) : nil
        let task = Task(id: id, text: txt, done: false, alarm: alarmStr,
                        created: ISO8601DateFormatter().string(from: Date()))
        fb.add(task)
        if alarmStr != nil { AlarmManager.shared.schedule(task) }
        newText = ""; hasAlarm = false; showPicker = false
    }

    func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - Task Row
struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(Color(hex: "00ffc8").opacity(0.35), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if task.done {
                        Circle().fill(Color(hex: "00ffc8").opacity(0.2)).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "00ffc8"))
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
                        Image(systemName: "bell.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "00aaff"))
                        Text(alarm)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "00aaff"))
                    }
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red.opacity(0.4))
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

// MARK: - Alarm Popup
struct AlarmPopupView: View {
    let task: Task
    let onDismiss: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "00ffc8").opacity(pulse ? 0.08 : 0.45), lineWidth: pulse ? 32 : 2)
                        .frame(width: 100, height: 100)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    Circle().fill(Color(hex: "00ffc8").opacity(0.12)).frame(width: 80, height: 80)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Color(hex: "00ffc8"))
                }
                .padding(.top, 36)
                .padding(.bottom, 20)
                .onAppear { pulse = true }

                Text("ALARM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "00ffc8").opacity(0.5))
                    .tracking(5)
                    .padding(.bottom, 10)

                Text(task.text)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                if let alarm = task.alarm {
                    Text(alarm)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .padding(.bottom, 32)
                }

                Button(action: onDismiss) {
                    Text("DISMISS")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "060a0f"))
                        .frame(width: 200, height: 50)
                        .background(Color(hex: "00ffc8"))
                        .cornerRadius(25)
                }
                .padding(.bottom, 40)
            }
            .frame(width: 320)
            .background(Color(hex: "0c1a1a"))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "00ffc8").opacity(0.25), lineWidth: 1))
        }
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
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}
