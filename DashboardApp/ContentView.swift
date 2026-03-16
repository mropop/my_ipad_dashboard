import SwiftUI

// MARK: - App Entry
@main
struct DashboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: "0a0f1a"), Color(hex: "060a0f")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            GeometryReader { geo in
                HStack(spacing: 14) {
                    // Left column: Clock
                    VStack(spacing: 14) {
                        ClockView()
                    }
                    .frame(width: geo.size.width * 0.48)

                    // Right column: Calendar + Todo
                    VStack(spacing: 14) {
                        CalendarView()
                        TodoView()
                    }
                    .frame(width: geo.size.width * 0.48)
                }
                .padding(14)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
}

// MARK: - Clock View
struct ClockView: View {
    @State private var time = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var hours: String {
        let h = Calendar.current.component(.hour, from: time) % 12
        return String(format: "%02d", h == 0 ? 12 : h)
    }
    var minutes: String { String(format: "%02d", Calendar.current.component(.minute, from: time)) }
    var seconds: String { String(format: "%02d", Calendar.current.component(.second, from: time)) }
    var ampm: String { Calendar.current.component(.hour, from: time) < 12 ? "AM" : "PM" }
    var dateStr: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d, yyyy"
        return f.string(from: time).uppercased()
    }
    var secondProgress: Double { Double(Calendar.current.component(.second, from: time)) / 59.0 }

    var body: some View {
        PanelView(accentColor: Color(hex: "00ffc8")) {
            VStack(alignment: .leading, spacing: 8) {
                // Label
                Text("SYSTEM TIME")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "00ffc8").opacity(0.4))
                    .tracking(3)

                // Big time
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(hours)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.5), radius: 10)
                    BlinkingColon()
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                    Text(minutes)
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .shadow(color: Color(hex: "00ffc8").opacity(0.5), radius: 10)
                }

                // Seconds + AM/PM row
                HStack(spacing: 12) {
                    Text(seconds)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                        .shadow(color: Color(hex: "00aaff").opacity(0.4), radius: 8)
                    Text(ampm)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8").opacity(0.5))
                }

                // Seconds progress bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "00aaff"), Color(hex: "00ffc8")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: g.size.width * secondProgress, height: 3)
                            .animation(.linear(duration: 1), value: secondProgress)
                    }
                }
                .frame(height: 3)
                .padding(.vertical, 4)

                // Date
                Text(dateStr)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .onReceive(timer) { t in time = t }
    }
}

// MARK: - Blinking Colon
struct BlinkingColon: View {
    @State private var visible = true
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Text(":")
            .opacity(visible ? 1 : 0)
            .frame(width: 24, alignment: .center)
            .onReceive(timer) { _ in visible.toggle() }
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @State private var displayMonth = Date()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dayNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth).uppercased()
    }

    var days: [(Int, Bool, Bool)] { // (day, isCurrentMonth, isToday)
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        let firstWeekday = cal.component(.weekday, from: start) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: displayMonth)!.count
        let prevDays = cal.range(of: .day, in: .month, for: cal.date(byAdding: .month, value: -1, to: displayMonth)!)!.count
        let today = cal.component(.day, from: Date())
        let todayMonth = cal.component(.month, from: Date())
        let thisMonth = cal.component(.month, from: displayMonth)
        let thisYear = cal.component(.year, from: displayMonth)
        let todayYear = cal.component(.year, from: Date())

        var result: [(Int, Bool, Bool)] = []
        for i in 0..<firstWeekday {
            result.append((prevDays - firstWeekday + 1 + i, false, false))
        }
        for d in 1...daysInMonth {
            let isToday = d == today && thisMonth == todayMonth && thisYear == todayYear
            result.append((d, true, isToday))
        }
        var next = 1
        while result.count < 42 { result.append((next, false, false)); next += 1 }
        return result
    }

    var body: some View {
        PanelView(accentColor: Color(hex: "00aaff")) {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text(monthLabel)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00aaff"))
                        .tracking(1)
                    Spacer()
                    HStack(spacing: 6) {
                        Button { changeMonth(-1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                        Button { changeMonth(1) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "00aaff"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "00aaff").opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }

                // Day names
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(dayNames, id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        ZStack {
                            if day.2 {
                                Circle()
                                    .fill(Color(hex: "00ffc8"))
                                    .frame(width: 24, height: 24)
                            }
                            Text("\(day.0)")
                                .font(.system(size: 11, weight: day.2 ? .bold : .regular, design: .monospaced))
                                .foregroundColor(day.2 ? Color(hex: "060a0f") : day.1 ? .white.opacity(0.55) : .white.opacity(0.15))
                        }
                        .frame(maxWidth: .infinity, minHeight: 24)
                    }
                }
            }
        }
    }

    func changeMonth(_ dir: Int) {
        displayMonth = Calendar.current.date(byAdding: .month, value: dir, to: displayMonth)!
    }
}

// MARK: - Todo View
struct TodoView: View {
    @State private var tasks: [Task] = {
        if let data = UserDefaults.standard.data(forKey: "swift_tasks"),
           let decoded = try? JSONDecoder().decode([Task].self, from: data) {
            return decoded
        }
        return []
    }()
    @State private var newText = ""

    var remaining: Int { tasks.filter { !$0.done }.count }

    var body: some View {
        PanelView(accentColor: Color(hex: "00ffc8")) {
            VStack(spacing: 10) {
                // Header
                HStack {
                    Text("TASKS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00ffc8"))
                        .tracking(2)
                    Spacer()
                    Text(remaining == 0 ? "All done!" : "\(remaining) left")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }

                // Input
                HStack(spacing: 8) {
                    TextField("Add task...", text: $newText)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "00ffc8").opacity(0.2), lineWidth: 1))
                        .onSubmit { addTask() }

                    Button(action: addTask) {
                        Text("ADD")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "00ffc8"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "00ffc8").opacity(0.12))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "00ffc8").opacity(0.3), lineWidth: 1))
                    }
                }

                // Task list
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(tasks) { task in
                            TaskRow(task: task, onToggle: { toggle(task) }, onDelete: { delete(task) })
                        }
                        if tasks.isEmpty {
                            Text("No tasks yet")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                                .padding(.top, 12)
                        }
                    }
                }
            }
        }
    }

    func addTask() {
        let t = newText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        tasks.insert(Task(text: t), at: 0)
        newText = ""
        save()
    }

    func toggle(_ task: Task) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i].done.toggle()
            save()
        }
    }

    func delete(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: "swift_tasks")
        }
    }
}

// MARK: - Task Row
struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(Color(hex: "00ffc8").opacity(0.4), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if task.done {
                        Circle()
                            .fill(Color(hex: "00ffc8").opacity(0.2))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "00ffc8"))
                    }
                }
            }

            Text(task.text)
                .font(.system(size: 13))
                .foregroundColor(task.done ? .white.opacity(0.3) : .white.opacity(0.85))
                .strikethrough(task.done, color: .white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.4))
                    .padding(4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .opacity(task.done ? 0.5 : 1)
    }
}

// MARK: - Panel View
struct PanelView<Content: View>: View {
    let accentColor: Color
    let content: () -> Content

    init(accentColor: Color, @ViewBuilder content: @escaping () -> Content) {
        self.accentColor = accentColor
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.18), lineWidth: 1))

            // Top accent line
            GeometryReader { g in
                LinearGradient(
                    colors: [.clear, accentColor, .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: g.size.width * 0.8, height: 1)
                .position(x: g.size.width / 2, y: 0)
                .opacity(0.6)
            }

            content()
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Model
struct Task: Identifiable, Codable {
    var id = UUID()
    var text: String
    var done: Bool = false
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
