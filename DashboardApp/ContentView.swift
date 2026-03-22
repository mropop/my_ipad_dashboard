import SwiftUI
import AudioToolbox
import AVFoundation
import CoreLocation

// MARK: - Config
let FIREBASE_URL = "https://my-todo-list-b567a-default-rtdb.asia-southeast1.firebasedatabase.app"
let FIREBASE_KEY = "AIzaSyDHKPTvVmsPsnd_em1al9YVzla5dMD56oA"

// MARK: - Task Model
struct Task: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var done: Bool
    var alarm: String?
    var created: String
}

// MARK: - Weather Manager
struct DayForecast: Identifiable {
    let id: Int
    let date: String      // "Mon", "Tue"...
    let high: Double
    let low: Double
    let icon: String
}

struct WeatherData {
    var temp: Double = 0
    var feelsLike: Double = 0
    var humidity: Int = 0
    var windSpeed: Double = 0
    var description: String = ""
    var icon: String = "cloud"
    var city: String = ""
    var forecast: [DayForecast] = []
}

// MARK: - Weather Theme
enum WeatherCondition {
    case clearDay, clearNight
    case partlyCloudy, cloudy, foggy
    case rainy, stormy, snowy
}

struct WeatherTheme {
    let condition: WeatherCondition
    let bgTop: Color
    let bgBottom: Color
    let accent: Color
    let accent2: Color
    let textColor: Color
    let panelBorder: Color
    let label: String

    static func manual(_ id: String) -> WeatherTheme {
        switch id {
        case "clearDay":     return from(code: 0, hour: 10, temp: 25)
        case "partlyCloudy": return from(code: 2, hour: 10, temp: 25)
        case "clearNight":   return from(code: 0, hour: 20, temp: 25)
        case "cloudy":       return from(code: 3, hour: 10, temp: 25)
        case "foggy":        return from(code: 45, hour: 10, temp: 25)
        case "rainy":        return from(code: 61, hour: 10, temp: 25)
        case "stormy":       return from(code: 95, hour: 10, temp: 25)
        case "cold":         return from(code: 1, hour: 10, temp: 10)
        default:             return from(code: 0, hour: 10, temp: 25)
        }
    }

    static func from(code: Int, hour: Int, temp: Double = 20, sunsetHour: Int = 18) -> WeatherTheme {
        let isNight = hour >= sunsetHour || hour < 6

        // Cold weather override — temp < 15°C regardless of condition
        if temp < 15 && code < 95 {
            return WeatherTheme(
                condition: .snowy,
                bgTop: Color(hex: "04080e"), bgBottom: Color(hex: "0a1828"),
                accent: Color(hex: "88ccff"), accent2: Color(hex: "5599dd"),
                textColor: Color(hex: "cce8ff"), panelBorder: Color(hex: "88ccff").opacity(0.18),
                label: "COLD · \(Int(temp))°C")
        }

        switch code {
        case 0, 1: // Clear
            if isNight {
                return WeatherTheme(
                    condition: .clearNight,
                    bgTop: Color(hex: "020810"), bgBottom: Color(hex: "0a2838"),
                    accent: Color(hex: "c8e8ff"), accent2: Color(hex: "4488bb"),
                    textColor: Color(hex: "c8e8ff"), panelBorder: Color(hex: "0088cc").opacity(0.2),
                    label: "MIDNIGHT SEA")
            } else {
                return WeatherTheme(
                    condition: .clearDay,
                    bgTop: Color(hex: "1a4a7a"), bgBottom: Color(hex: "2a7ab0"),
                    accent: Color(hex: "88ddff"), accent2: Color(hex: "ccf0ff"),
                    textColor: Color(hex: "eef8ff"), panelBorder: Color(hex: "88ddff").opacity(0.35),
                    label: "CLEAR SKY")
            }
        case 2: // Partly Cloudy
            if isNight {
                return WeatherTheme(
                    condition: .partlyCloudy,
                    bgTop: Color(hex: "040a14"), bgBottom: Color(hex: "0a1828"),
                    accent: Color(hex: "88aadd"), accent2: Color(hex: "5577aa"),
                    textColor: Color(hex: "c0d4ee"), panelBorder: Color(hex: "88aadd").opacity(0.18),
                    label: "PARTLY CLOUDY")
            } else {
                return WeatherTheme(
                    condition: .partlyCloudy,
                    bgTop: Color(hex: "1a3a5a"), bgBottom: Color(hex: "2a6090"),
                    accent: Color(hex: "77ccff"), accent2: Color(hex: "bbeeff"),
                    textColor: Color(hex: "e8f6ff"), panelBorder: Color(hex: "77ccff").opacity(0.3),
                    label: "PARTLY CLOUDY")
            }
        case 3: // Overcast
            return WeatherTheme(
                condition: .cloudy,
                bgTop: Color(hex: "1a2030"), bgBottom: Color(hex: "2a3548"),
                accent: Color(hex: "aabbcc"), accent2: Color(hex: "8899aa"),
                textColor: Color(hex: "d8e8f0"), panelBorder: Color(hex: "aabbcc").opacity(0.22),
                label: "OVERCAST")
        case 45, 48: // Fog
            return WeatherTheme(
                condition: .foggy,
                bgTop: Color(hex: "0a0c10"), bgBottom: Color(hex: "141820"),
                accent: Color(hex: "99aabb"), accent2: Color(hex: "778899"),
                textColor: Color(hex: "d0d8e0"), panelBorder: Color(hex: "99aabb").opacity(0.12),
                label: "MISTY")
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: // Rain
            return WeatherTheme(
                condition: .rainy,
                bgTop: Color(hex: "050810"), bgBottom: Color(hex: "081016"),
                accent: Color(hex: "6699dd"), accent2: Color(hex: "4477bb"),
                textColor: Color(hex: "c8d8ff"), panelBorder: Color(hex: "6699dd").opacity(0.2),
                label: "RAINY")
        case 71, 73, 75, 77, 85, 86: // Snow
            return WeatherTheme(
                condition: .snowy,
                bgTop: Color(hex: "060810"), bgBottom: Color(hex: "0a1020"),
                accent: Color(hex: "aaccff"), accent2: Color(hex: "88aadd"),
                textColor: Color(hex: "ddeeff"), panelBorder: Color(hex: "aaccff").opacity(0.2),
                label: "SNOWY")
        case 95, 96, 99: // Storm
            return WeatherTheme(
                condition: .stormy,
                bgTop: Color(hex: "040608"), bgBottom: Color(hex: "0a0e18"),
                accent: Color(hex: "aabbdd"), accent2: Color(hex: "6688cc"),
                textColor: Color(hex: "c0d0ee"), panelBorder: Color(hex: "aabbdd").opacity(0.2),
                label: "STORM")
        default:
            return WeatherTheme(
                condition: .cloudy,
                bgTop: Color(hex: "060a0f"), bgBottom: Color(hex: "0a1020"),
                accent: Color(hex: "00ffc8"), accent2: Color(hex: "00aaff"),
                textColor: .white, panelBorder: Color(hex: "00ffc8").opacity(0.18),
                label: "")
        }
    }
}

// Shared observable theme
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var theme: WeatherTheme = WeatherTheme.from(code: 0, hour: Calendar.current.component(.hour, from: Date()))
    @Published var weatherCode: Int = 0
    @Published var manualTheme: String? = nil
    var sunsetHour: Int = 18
    var lastTemp: Double = 25

    static let manualOptions: [(String, String, String)] = [  // (id, emoji, name)
        ("clearDay",     "☀️", "Clear"),
        ("partlyCloudy", "🌤", "Partly"),
        ("clearNight",   "🌙", "Night"),
        ("cloudy",       "☁️", "Overcast"),
        ("foggy",        "🌫", "Misty"),
        ("rainy",        "🌧", "Rain"),
        ("stormy",       "⛈", "Storm"),
        ("cold",         "🥶", "Cold"),
    ]

    func update(code: Int, temp: Double? = nil) {
        weatherCode = code
        if let t = temp { lastTemp = t }
        guard manualTheme == nil else { return }
        applyAutoTheme()
    }

    // Called every minute by clock — just re-check hour vs sunsetHour
    func refreshHour() {
        guard manualTheme == nil else { return }
        applyAutoTheme()
    }

    private func applyAutoTheme() {
        let hour = Calendar.current.component(.hour, from: Date())
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 2.0)) {
                self.theme = WeatherTheme.from(
                    code: self.weatherCode,
                    hour: hour,
                    temp: self.lastTemp,
                    sunsetHour: self.sunsetHour)
            }
        }
    }

    func setManual(_ id: String?) {
        manualTheme = id
        if let id = id {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 2.0)) {
                    self.theme = WeatherTheme.manual(id)
                }
            }
        } else {
            applyAutoTheme()
        }
    }
}


class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: WeatherData? = nil
    @Published var status: String = "Locating..."
    @Published var city: String = ""
    private var locationManager = CLLocationManager()
    private var fetchTimer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            self.status = "Location denied"
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        locationManager.stopUpdatingLocation()
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        fetchTimer?.invalidate()
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
        // Reverse geocode for city name
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self = self else { return }
            let name = placemarks?.first?.locality
                ?? placemarks?.first?.administrativeArea
                ?? placemarks?.first?.country
                ?? ""
            DispatchQueue.main.async {
                self.city = name
                self.weather?.city = name  // also update in struct
            }
        }
    }

    func fetchWeather(lat: Double, lon: Double) {
        // Open-Meteo — current + 5 day forecast + feels like + humidity + wind
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,apparent_temperature,weathercode,windspeed_10m,relativehumidity_2m" +
            "&daily=weathercode,temperature_2m_max,temperature_2m_min,sunset" +
            "&temperature_unit=celsius&windspeed_unit=kmh&forecast_days=6&timezone=auto"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            guard let self = self, let data = data, err == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double,
                  let feels = current["apparent_temperature"] as? Double,
                  let humidity = current["relativehumidity_2m"] as? Int,
                  let wind = current["windspeed_10m"] as? Double,
                  let code = current["weathercode"] as? Int else { return }
            let (desc, icon) = Self.weatherInfo(code: code)

            // Parse 5-day forecast (skip today = index 0)
            var forecast: [DayForecast] = []
            if let daily = json["daily"] as? [String: Any],
               let dates = daily["time"] as? [String],
               let codes = daily["weathercode"] as? [Int],
               let highs = daily["temperature_2m_max"] as? [Double],
               let lows = daily["temperature_2m_min"] as? [Double] {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let df2 = DateFormatter()
                df2.dateFormat = "EEE"
                for i in 1..<min(6, dates.count) {
                    let dayLabel = df.date(from: dates[i]).flatMap { df2.string(from: $0) } ?? "Day \(i)"
                    let (_, ic) = Self.weatherInfo(code: codes[i])
                    forecast.append(DayForecast(id: i, date: dayLabel.uppercased(), high: highs[i], low: lows[i], icon: ic))
                }
            }

            // Parse sunset hour for today
            var sunsetHour = 18
            if let daily = json["daily"] as? [String: Any],
               let sunsets = daily["sunset"] as? [String],
               let first = sunsets.first {
                // Format: "2026-03-20T18:15" — extract hour
                let parts = first.split(separator: "T")
                if parts.count == 2 {
                    let timePart = String(parts[1])
                    if let h = Int(timePart.prefix(2)) {
                        sunsetHour = h
                    }
                }
            }
            ThemeManager.shared.sunsetHour = sunsetHour

            DispatchQueue.main.async {
                self.weather = WeatherData(
                    temp: temp, feelsLike: feels, humidity: humidity,
                    windSpeed: wind, description: desc, icon: icon,
                    city: self.weather?.city ?? "", forecast: forecast
                )
                self.status = "ok"
                ThemeManager.shared.update(code: code, temp: temp)
            }
        }.resume()
    }

    static func weatherInfo(code: Int) -> (String, String) {
        switch code {
        case 0:             return ("Clear",         "sun.max.fill")
        case 1:             return ("Mostly Clear",  "sun.max.fill")
        case 2:             return ("Partly Cloudy", "cloud.sun.fill")
        case 3:             return ("Overcast",      "cloud.fill")
        case 45, 48:        return ("Foggy",         "cloud.fog.fill")
        case 51, 53, 55:    return ("Drizzle",       "cloud.drizzle.fill")
        case 61, 63, 65:    return ("Rain",          "cloud.rain.fill")
        case 71, 73, 75:    return ("Snow",          "cloud.snow.fill")
        case 80, 81, 82:    return ("Showers",       "cloud.heavyrain.fill")
        case 95:            return ("Thunderstorm",  "cloud.bolt.fill")
        case 96, 99:        return ("Hail Storm",    "cloud.bolt.rain.fill")
        default:            return ("Cloudy",        "cloud.fill")
        }
    }
}


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

// MARK: - Available alarm sounds (scanned from system)
struct AlarmSound: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
}

func scanSystemSounds() -> [AlarmSound] {
    let fm = FileManager.default
    var results: [AlarmSound] = []
    let dir = "/Library/Ringtones"
    guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
        return [AlarmSound(id: "default", name: "Default", path: "/System/Library/Audio/UISounds/alarm.caf")]
    }
    for file in files.sorted() {
        let ext = (file as NSString).pathExtension.lowercased()
        guard ["caf","aiff","aif","mp3","m4a","m4r","wav"].contains(ext) else { continue }
        let fullPath = dir + "/" + file
        let name = (file as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        results.append(AlarmSound(id: fullPath, name: name, path: fullPath))
    }
    return results.isEmpty
        ? [AlarmSound(id: "default", name: "Default", path: "/System/Library/Audio/UISounds/alarm.caf")]
        : results
}

let availableAlarmSounds: [AlarmSound] = scanSystemSounds()

// MARK: - Alarm Manager
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    @Published var firingAlarm: Task? = nil
    @Published var selectedSoundId: String = "alarm"
    private var timers: [String: Timer] = [:]
    var audioPlayer: AVAudioPlayer?

    init() {
        // Load saved sound preference — default to first alarm sound found
        let saved = UserDefaults.standard.string(forKey: "alarm_sound_id")
        if let saved = saved, availableAlarmSounds.contains(where: { $0.id == saved }) {
            selectedSoundId = saved
        } else {
            // Pick a good default — prefer alarm.caf
            selectedSoundId = availableAlarmSounds.first { $0.path.contains("alarm") }?.id
                ?? availableAlarmSounds.first?.id ?? ""
        }
    }

    func saveSelectedSound(_ id: String) {
        selectedSoundId = id
        UserDefaults.standard.set(id, forKey: "alarm_sound_id")
    }

    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        firingAlarm = nil
    }

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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session: \(error)") }

        // selectedSoundId is the full path
        let pathsToTry: [String] = [selectedSoundId] + availableAlarmSounds.map { $0.path }
        var player: AVAudioPlayer?
        for path in pathsToTry where !path.isEmpty {
            if let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) {
                player = p; break
            }
        }

        if let player = player {
            player.numberOfLoops = 5
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } else {
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                    AudioServicesPlaySystemSound(1304)
                }
            }
        }
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
    @StateObject private var themeMgr = ThemeManager.shared

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                // Dynamic animated background
                LinearGradient(
                    colors: [themeMgr.theme.bgTop, themeMgr.theme.bgBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2), value: themeMgr.theme.label)

                // Weather-specific background animation
                WeatherBackgroundView(condition: themeMgr.theme.condition)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    ClockView(compact: isLandscape)
                        .frame(height: isLandscape ? geo.size.height * 0.50 : geo.size.height * 0.50)

                    HStack(spacing: 10) {
                        CalendarWeatherView(compact: isLandscape)
                            .frame(width: geo.size.width * 0.48)
                        TodoView()
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(10)

                if let alarm = alarmMgr.firingAlarm {
                    AlarmPopupView(task: alarm) {
                        alarmMgr.firingAlarm = nil
                    }
                }
            }
        }
    }
}

// MARK: - Weather Background Animations
struct WeatherBackgroundView: View {
    let condition: WeatherCondition
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if scenePhase == .active {
                switch condition {
                case .rainy:
                    RainView()
                case .stormy:
                    StormView()
                case .snowy:
                    SnowView()
                case .clearDay:
                    OceanWaveView(color: Color(hex: "44aaff"))
                case .clearNight:
                    StarfieldView()
                case .partlyCloudy:
                    PartlyCloudyView()
                case .foggy:
                    FogView()
                case .cloudy:
                    CloudyView()
                }
            }
        }
    }
}

// MARK: - Rain Animation
struct RainView: View {
    let drops = (0..<50).map { _ in RainDrop() }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/24.0)) { tl in
            let now = tl.date.timeIntervalSince1970
            Canvas { ctx, size in
                for drop in drops {
                    let t = (now + drop.offset).truncatingRemainder(dividingBy: drop.duration) / drop.duration
                    let x = drop.x * size.width
                    let y = t * (size.height + 40) - 20
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - 1, y: y + drop.length))
                    ctx.stroke(path, with: .color(.white.opacity(drop.opacity)), lineWidth: drop.width)
                }
            }
        }
    }
}

struct RainDrop {
    let x = Double.random(in: 0...1)
    let length = Double.random(in: 12...28)
    let duration = Double.random(in: 0.4...1.0)
    let opacity = Double.random(in: 0.15...0.45)
    let width = Double.random(in: 0.5...1.5)
    let offset = Double.random(in: 0...3.0)  // stagger start
}

// MARK: - Storm Animation
struct StormView: View {
    @State private var flash = false
    var body: some View {
        ZStack {
            RainView()
            // Lightning flash
            Color.white.opacity(flash ? 0.12 : 0)
                .ignoresSafeArea()
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...7), repeats: true) { _ in
                        withAnimation(.easeIn(duration: 0.05)) { flash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.1)) { flash = false }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeIn(duration: 0.05)) { flash = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { flash = false }
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Snow Animation
struct SnowView: View {
    let flakes = (0..<35).map { _ in SnowFlake() }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/20.0)) { tl in
            let now = tl.date.timeIntervalSince1970
            ZStack {
                // Snowflakes via Canvas
                Canvas { ctx, size in
                    for flake in flakes {
                        let progress = ((now + flake.driftOffset).truncatingRemainder(dividingBy: flake.duration)) / flake.duration
                        let drift = sin(now * flake.driftSpeed + flake.driftOffset) * 20
                        let x = flake.x * size.width + drift
                        let y = progress * (size.height + 20) - 10
                        let rect = CGRect(x: x - flake.size/2, y: y - flake.size/2, width: flake.size, height: flake.size)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(flake.opacity)))
                    }
                }
                // Frost glow at bottom
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color(hex: "88ccff").opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.3)
                    .position(x: geo.size.width/2, y: geo.size.height * 0.87)
                    // Icy shimmer top
                    let shimmer = CGFloat(sin(now * 0.5) * 0.03)
                    Color(hex: "aaddff").opacity(Double(shimmer) + 0.02)
                        .blendMode(.screen)
                }
            }
        }
    }
}

struct SnowFlake {
    let x = Double.random(in: 0...1)
    let size = Double.random(in: 2...6)
    let duration = Double.random(in: 4...10)
    let opacity = Double.random(in: 0.2...0.6)
    let driftSpeed = Double.random(in: 0.5...1.5)
    let driftOffset = Double.random(in: 0...6.28)
}

// MARK: - Ocean Wave Animation
struct OceanWaveView: View {
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/20.0)) { tl in
            let t = tl.date.timeIntervalSince1970
            let phase = t * 0.8
            let sunBob = CGFloat(sin(t * 0.6) * 5)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Yellow sun glow
                    Circle()
                        .fill(Color(hex: "ffdd44").opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 35)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.18 + sunBob)
                    // Yellow sun
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: "ffffaa"), Color(hex: "ffee44"), Color(hex: "ffbb22")],
                            center: .center, startRadius: 0, endRadius: 26))
                        .frame(width: 50, height: 50)
                        .shadow(color: Color(hex: "ffcc33").opacity(0.8), radius: 20)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.16 + sunBob)
                    // Waves
                    WaveShape(phase: phase, amplitude: 8, frequency: 1.2)
                        .fill(color.opacity(0.15))
                        .frame(height: 60)
                    WaveShape(phase: phase + 1.5, amplitude: 6, frequency: 0.9)
                        .fill(color.opacity(0.1))
                        .frame(height: 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

struct WaveShape: Shape {
    var phase: Double
    var amplitude: Double
    var frequency: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        for x in stride(from: 0, to: rect.width, by: 2) {
            let y = amplitude * sin(frequency * x / rect.width * 2 * .pi + phase) + rect.height * 0.5
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Starfield Animation
struct StarfieldView: View {
    let stars = (0..<80).map { _ in Star() }  // reduced for power saving
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/10.0)) { tl in
            let now = tl.date.timeIntervalSince1970
            ZStack {
                // Stars via Canvas — spread across full top 70%
                Canvas { ctx, size in
                    for star in stars {
                        let pulse = 0.3 + 0.7 * abs(sin(now * star.speed + star.offset))
                        let rect = CGRect(
                            x: star.x * size.width - star.size/2,
                            y: star.y * size.height * 0.7 - star.size/2,
                            width: star.size, height: star.size)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(pulse * star.opacity)))
                        // Add cross sparkle for brighter stars
                        if star.size > 2.5 {
                            let cx = star.x * size.width
                            let cy = star.y * size.height * 0.7
                            let len = star.size * 2 * pulse
                            var h = Path(); h.move(to: CGPoint(x: cx-len, y: cy)); h.addLine(to: CGPoint(x: cx+len, y: cy))
                            var v = Path(); v.move(to: CGPoint(x: cx, y: cy-len)); v.addLine(to: CGPoint(x: cx, y: cy+len))
                            ctx.stroke(h, with: .color(.white.opacity(pulse * 0.4)), lineWidth: 0.5)
                            ctx.stroke(v, with: .color(.white.opacity(pulse * 0.4)), lineWidth: 0.5)
                        }
                    }
                }
                // Moon — visible SwiftUI view
                GeometryReader { geo in
                    ZStack {
                        // Moon glow
                        Circle()
                            .fill(Color(hex: "c8e0ff").opacity(0.25))
                            .frame(width: 90, height: 90)
                            .blur(radius: 18)
                            .position(x: geo.size.width * 0.78, y: geo.size.height * 0.18)
                        // Moon body
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color(hex: "f0f8ff"), Color(hex: "d0e8ff"), Color(hex: "b8d4f0")],
                                center: .center, startRadius: 0, endRadius: 22))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "aaccff").opacity(0.6), radius: 14)
                            .position(x: geo.size.width * 0.78, y: geo.size.height * 0.18)
                        // Moon crater details
                        Circle()
                            .fill(Color(hex: "b0ccee").opacity(0.3))
                            .frame(width: 10, height: 10)
                            .position(x: geo.size.width * 0.78 + 8, y: geo.size.height * 0.18 - 6)
                        Circle()
                            .fill(Color(hex: "b0ccee").opacity(0.2))
                            .frame(width: 6, height: 6)
                            .position(x: geo.size.width * 0.78 - 8, y: geo.size.height * 0.18 + 5)
                        // Moon reflection on water
                        let shimmer = CGFloat(sin(now * 0.8) * 3)
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "c8e0ff").opacity(0.18), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: 80)
                            .blur(radius: 3)
                            .offset(x: shimmer)
                            .position(x: geo.size.width * 0.78, y: geo.size.height * 0.72)
                    }
                }
            }
        }
    }
}

struct Star {
    let x = Double.random(in: 0...1)
    let y = Double.random(in: 0...1)
    let size = Double.random(in: 0.8...3.5)
    let opacity = Double.random(in: 0.4...1.0)
    let speed = Double.random(in: 0.3...1.5)
    let offset = Double.random(in: 0...6.28)
}

// MARK: - Fog Animation
struct FogView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/8.0)) { tl in
            FogCanvas(t: tl.date.timeIntervalSince1970)
        }
    }
}
struct FogCanvas: View {
    let t: Double
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: geo.size.width * 1.4, height: 120)
                    .offset(x: CGFloat(sin(t * 0.08) * 60) - 100, y: geo.size.height * 0.3)
                    .blur(radius: 30)
                Ellipse()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: geo.size.width * 1.4, height: 120)
                    .offset(x: CGFloat(sin(t * 0.08 + 1.2) * 60) - 40, y: geo.size.height * 0.36)
                    .blur(radius: 30)
                Ellipse()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: geo.size.width * 1.4, height: 120)
                    .offset(x: CGFloat(sin(t * 0.08 + 2.4) * 60) + 20, y: geo.size.height * 0.42)
                    .blur(radius: 30)
            }
        }
    }
}

// MARK: - Cloud Shape (simple ellipse clusters)
struct CloudShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()

        let configs: [(CGFloat,CGFloat,CGFloat,CGFloat)] = seed == 1 ? [
            (0.15,0.65,0.22,0.50),(0.38,0.42,0.26,0.55),(0.62,0.38,0.28,0.58),(0.82,0.55,0.22,0.48)
        ] : seed == 2 ? [
            (0.18,0.68,0.24,0.48),(0.40,0.44,0.28,0.54),(0.64,0.36,0.26,0.56),(0.85,0.58,0.20,0.46)
        ] : seed == 3 ? [
            (0.12,0.62,0.20,0.46),(0.34,0.40,0.26,0.52),(0.58,0.34,0.28,0.56),(0.80,0.50,0.22,0.50)
        ] : seed == 4 ? [
            (0.16,0.66,0.22,0.50),(0.38,0.42,0.28,0.56),(0.64,0.36,0.26,0.54),(0.84,0.56,0.20,0.46)
        ] : [
            (0.14,0.64,0.22,0.48),(0.36,0.40,0.26,0.54),(0.60,0.36,0.28,0.56),(0.82,0.52,0.22,0.48)
        ]
        // configs: (xFrac, yFrac, rxFrac, ryFrac)

        for cfg in configs {
            let cx = cfg.0 * w
            let cy = cfg.1 * h
            let rx = cfg.2 * w
            let ry = cfg.3 * h
            path.addEllipse(in: CGRect(x: cx-rx, y: cy-ry, width: rx*2, height: ry*2))
        }
        // base rect to fill bottom
        path.addRect(CGRect(x: 0, y: h*0.55, width: w, height: h*0.45))
        return path
    }
}


struct PartlyCloudyView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/10.0)) { tl in
            PartlyCloudyCanvas(t: tl.date.timeIntervalSince1970)
        }
    }
}

struct PartlyCloudyCanvas: View {
    let t: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let c1x = w * 0.38 + CGFloat(t * 3).truncatingRemainder(dividingBy: w + 200) - 100
            let c2x = w * 0.65 + CGFloat(t * 5).truncatingRemainder(dividingBy: w + 180) - 90
            let c3x = w * 0.20 + CGFloat(t * 4).truncatingRemainder(dividingBy: w + 150) - 75
            ZStack {
                // Sun glow
                Circle()
                    .fill(Color(hex: "ffdd44").opacity(0.25))
                    .frame(width: 130, height: 130)
                    .blur(radius: 28)
                    .position(x: w * 0.72, y: h * 0.2)
                // Sun
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "ffffaa"), Color(hex: "ffee44"), Color(hex: "ffbb22")],
                        center: .center, startRadius: 0, endRadius: 22))
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(hex: "ffcc33").opacity(0.8), radius: 18)
                    .position(x: w * 0.72, y: h * 0.18)
                // Cloud 1
                CloudShape(seed: 1)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 60)
                    .position(x: c1x, y: h * 0.16)
                // Cloud 2
                CloudShape(seed: 2)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 150, height: 45)
                    .position(x: c2x, y: h * 0.27)
                // Cloud 3
                CloudShape(seed: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 120, height: 36)
                    .position(x: c3x, y: h * 0.1)
            }
        }
    }
}

// MARK: - Cloudy Animation
struct CloudyView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0/10.0)) { tl in
            CloudyCanvas(t: tl.date.timeIntervalSince1970)
        }
    }
}

struct CloudyCanvas: View {
    let t: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let c1x = CGFloat(t * 2.5).truncatingRemainder(dividingBy: w + 260) - 130
            let c2x = CGFloat(t * 1.8 + 200).truncatingRemainder(dividingBy: w + 220) - 110
            let c3x = CGFloat(t * 3.2 + 400).truncatingRemainder(dividingBy: w + 200) - 100
            let c4x = CGFloat(t * 2.0 + 600).truncatingRemainder(dividingBy: w + 180) - 90
            let c5x = CGFloat(t * 1.5 + 100).truncatingRemainder(dividingBy: w + 160) - 80
            ZStack {
                CloudShape(seed: 1).fill(Color.white.opacity(0.06))
                    .frame(width: 240, height: 70).position(x: c1x, y: h * 0.1)
                CloudShape(seed: 2).fill(Color.white.opacity(0.05))
                    .frame(width: 190, height: 58).position(x: c2x, y: h * 0.2)
                CloudShape(seed: 3).fill(Color.white.opacity(0.06))
                    .frame(width: 160, height: 50).position(x: c3x, y: h * 0.06)
                CloudShape(seed: 4).fill(Color.white.opacity(0.04))
                    .frame(width: 210, height: 62).position(x: c4x, y: h * 0.3)
                CloudShape(seed: 5).fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 44).position(x: c5x, y: h * 0.16)
            }
        }
    }
}

// MARK: - Clock
struct ClockView: View {
    var compact: Bool = false
    @State private var now = Date()
    @State private var colonOn = true
    @StateObject private var themeMgr = ThemeManager.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var h: String { String(format: "%02d", Calendar.current.component(.hour, from: now)) }
    var m: String { String(format: "%02d", Calendar.current.component(.minute, from: now)) }
    var s: String { String(format: "%02d", Calendar.current.component(.second, from: now)) }
    var secProg: Double { Double(Calendar.current.component(.second, from: now)) / 59.0 }
    var dateStr: String {
        let f = DateFormatter()
        f.dateFormat = compact ? "EEE · MMM d, yyyy" : "EEEE  ·  MMMM d, yyyy"
        return f.string(from: now).uppercased()
    }

    var clockSize: CGFloat { compact ? 120 : 110 }
    var secSize: CGFloat { compact ? 36 : 32 }

    var body: some View {
        PanelView {
            GeometryReader { geo in
                VStack(spacing: 6) {
                    Spacer()
                    // Theme label
                    if !themeMgr.theme.label.isEmpty {
                        Text(themeMgr.theme.label)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(themeMgr.theme.accent.opacity(0.4))
                            .tracking(3)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Spacer()
                        Text("\(h):\(m)")
                            .font(.system(size: 999, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.01)
                            .lineLimit(1)
                            .foregroundColor(themeMgr.theme.accent)
                            .shadow(color: themeMgr.theme.accent.opacity(0.4), radius: 16)
                            .frame(width: geo.size.width * 0.78)
                            .animation(.easeInOut(duration: 2), value: themeMgr.theme.label)
                        Text(s)
                            .font(.system(size: geo.size.height * 0.30, weight: .bold, design: .monospaced))
                            .foregroundColor(themeMgr.theme.accent2)
                            .frame(width: geo.size.width * 0.18)
                            .padding(.bottom, geo.size.height * 0.08)
                        Spacer()
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [themeMgr.theme.accent2, themeMgr.theme.accent],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * secProg, height: 3)
                                .animation(.linear(duration: 1), value: secProg)
                        }
                    }
                    .frame(height: 3)
                    Text(dateStr)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(themeMgr.theme.textColor.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onReceive(timer) { t in
            now = t
            colonOn = Calendar.current.component(.second, from: t) % 2 == 0
            if Calendar.current.component(.second, from: t) == 0 {
                ThemeManager.shared.refreshHour()
            }
        }
    }
}

// MARK: - Weather Widget
struct WeatherWidgetView: View {
    @ObservedObject var manager: WeatherManager
    var compact: Bool = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        Group {
            if let w = manager.weather {
                VStack(spacing: compact ? 5 : 8) {
                    // Current weather row
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: w.icon)
                            .font(.system(size: compact ? 24 : 32))
                            .foregroundColor(iconColor(w.icon))
                            .frame(width: compact ? 30 : 40)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(String(format: "%.0f°", w.temp))
                                    .font(.system(size: compact ? 26 : 36, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("C")
                                    .font(.system(size: compact ? 11 : 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            Text(w.description.uppercased())
                                .font(.system(size: compact ? 8 : 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                            let cityName = manager.city.isEmpty ? w.city : manager.city
                            if !cityName.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(theme.theme.accent.opacity(0.6))
                                    Text(cityName)
                                        .font(.system(size: compact ? 9 : 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(theme.theme.accent.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "thermometer.medium")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(String(format: "Feels %.0f°", w.feelsLike))
                                    .font(.system(size: compact ? 8 : 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            HStack(spacing: compact ? 5 : 8) {
                                HStack(spacing: 2) {
                                    Image(systemName: "humidity.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(theme.theme.accent2.opacity(0.6))
                                    Text("\(w.humidity)%")
                                        .font(.system(size: compact ? 8 : 9, design: .monospaced))
                                        .foregroundColor(theme.theme.accent2.opacity(0.6))
                                }
                                HStack(spacing: 2) {
                                    Image(systemName: "wind")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text(String(format: "%.0fkm/h", w.windSpeed))
                                        .font(.system(size: compact ? 8 : 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                    }

                    // Smaller spacer between current weather and forecast
                    Spacer(minLength: 4)

                    if !w.forecast.isEmpty {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
                        HStack(spacing: 4) {
                            ForEach(w.forecast) { day in
                                VStack(spacing: compact ? 1 : 3) {
                                    Text(day.date)
                                        .font(.system(size: compact ? 7 : 8, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.35))
                                    Image(systemName: day.icon)
                                        .font(.system(size: compact ? 11 : 14))
                                        .foregroundColor(iconColor(day.icon))
                                    Text(String(format: "%.0f°", day.high))
                                        .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(String(format: "%.0f°", day.low))
                                        .font(.system(size: compact ? 8 : 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.2))
                    Text(manager.status.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func iconColor(_ icon: String) -> Color {
        if icon.contains("sun") { return Color(hex: "FFD700") }
        if icon.contains("bolt") { return Color(hex: "FFD700") }
        if icon.contains("snow") { return Color(hex: "B0E0FF") }
        if icon.contains("rain") || icon.contains("drizzle") { return Color(hex: "00aaff") }
        if icon.contains("fog") { return Color.white.opacity(0.5) }
        return Color.white.opacity(0.6)
    }
}

// MARK: - Calendar
struct CalendarView: View {
    var compact: Bool = false
    @State private var display = Date()
    @ObservedObject private var theme = ThemeManager.shared
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    private let dn = ["Su","Mo","Tu","We","Th","Fr","Sa"]

    var label: String {
        let f = DateFormatter()
        f.dateFormat = compact ? "MMM yyyy" : "MMMM yyyy"
        return f.string(from: display).uppercased()
    }

    var cellSize: CGFloat { compact ? 18 : 22 }
    var fontSize: CGFloat { compact ? 9 : 10 }

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
        VStack(spacing: compact ? 4 : 6) {
            HStack {
                Text(label)
                    .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.theme.accent2)
                Spacer()
                HStack(spacing: 3) {
                    Button { display = Calendar.current.date(byAdding: .month, value: -1, to: display)! } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: compact ? 10 : 12, weight: .semibold))
                            .foregroundColor(theme.theme.accent2)
                            .frame(width: compact ? 20 : 26, height: compact ? 20 : 26)
                            .background(theme.theme.accent2.opacity(0.1))
                            .cornerRadius(5)
                    }
                    Button { display = Calendar.current.date(byAdding: .month, value: 1, to: display)! } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: compact ? 10 : 12, weight: .semibold))
                            .foregroundColor(theme.theme.accent2)
                            .frame(width: compact ? 20 : 26, height: compact ? 20 : 26)
                            .background(theme.theme.accent2.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
            }
            LazyVGrid(columns: cols, spacing: 1) {
                ForEach(dn, id: \.self) { d in
                    Text(d)
                        .font(.system(size: compact ? 8 : 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    ZStack {
                        if day.2 {
                            Circle().fill(theme.theme.accent).frame(width: cellSize, height: cellSize)
                        }
                        Text("\(day.0)")
                            .font(.system(size: fontSize, weight: day.2 ? .bold : .regular))
                            .foregroundColor(day.2 ? Color(hex: "060a0f") : day.1 ? .white.opacity(0.55) : .white.opacity(0.15))
                    }
                    .frame(maxWidth: .infinity, minHeight: cellSize)
                }
            }
        }
    }
}

// MARK: - Calendar + Weather combined
struct CalendarWeatherView: View {
    var compact: Bool = false
    @StateObject private var weather = WeatherManager()
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        PanelView() {
            VStack(spacing: compact ? 6 : 10) {
                CalendarView(compact: compact)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)

                VStack(spacing: 4) {
                    Text("WEATHER")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.theme.accent2.opacity(0.4))
                        .tracking(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WeatherWidgetView(manager: weather, compact: compact)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Todo
struct TodoView: View {
    @StateObject private var fb = FirebaseManager()
    @ObservedObject private var alarmMgr = AlarmManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var newText = ""
    @State private var hasAlarm = false
    @State private var pendingAlarm = Date()
    @State private var showPicker = false
    @State private var showSoundPicker = false
    @State private var showThemePicker = false
    @State private var filterMode = "all"
    @State private var previewPlayer: AVAudioPlayer?

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
        PanelView() {
            ZStack {
                VStack(spacing: 8) {
                // Header
                HStack {
                    Text("TASKS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.theme.accent)
                        .tracking(2)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(fb.connected ? theme.theme.accent : Color.gray)
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

                // Filter tabs + sound button + theme button
                HStack(spacing: 4) {
                    ForEach([("all","All"),("pending","Pending"),("done","Done"),("alarm","Alarm")], id: \.0) { k, l in
                        Button { filterMode = k } label: {
                            Text(l)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(filterMode == k ? Color(hex: "060a0f") : .white.opacity(0.4))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(filterMode == k ? theme.theme.accent : Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .animation(.easeInOut(duration: 0.3), value: theme.theme.label)
                        }
                    }
                    Spacer()
                    // Sound picker button
                    Button { showSoundPicker.toggle(); showThemePicker = false } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "music.note")
                                .font(.system(size: 9))
                            Text(availableAlarmSounds.first { $0.id == alarmMgr.selectedSoundId }?.name ?? "Alarm")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(theme.theme.accent2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(theme.theme.accent2.opacity(0.08))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.theme.accent2.opacity(0.2), lineWidth: 1))
                    }
                    // Theme toggle button
                    Button { showThemePicker.toggle(); showSoundPicker = false } label: {
                        HStack(spacing: 3) {
                            Image(systemName: theme.manualTheme == nil ? "wand.and.stars" : "paintpalette.fill")
                                .font(.system(size: 9))
                            Text(theme.manualTheme == nil ? "AUTO" : "THEME")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(theme.theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(theme.theme.accent.opacity(0.1))
                        .cornerRadius(5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.theme.accent.opacity(0.25), lineWidth: 1))
                    }
                }

                // Sound picker dropdown
                if showSoundPicker {
                    VStack(spacing: 4) {
                        Text("ALARM SOUND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)
                        ScrollView {
                            VStack(spacing: 3) {
                                ForEach(availableAlarmSounds) { sound in
                                    HStack {
                                        Image(systemName: alarmMgr.selectedSoundId == sound.id ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(alarmMgr.selectedSoundId == sound.id ? theme.theme.accent : .white.opacity(0.3))
                                        Text(sound.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(alarmMgr.selectedSoundId == sound.id ? theme.theme.accent : .white.opacity(0.7))
                                        Spacer()
                                        Button { previewSound(sound) } label: {
                                            Image(systemName: "play.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(theme.theme.accent2.opacity(0.7))
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(alarmMgr.selectedSoundId == sound.id ? theme.theme.accent.opacity(0.08) : Color.clear)
                                    .cornerRadius(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture { alarmMgr.saveSelectedSound(sound.id) }
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.theme.accent2.opacity(0.15), lineWidth: 1))
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
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.theme.accent.opacity(0.2), lineWidth: 1))
                        .onSubmit { addTask() }

                    Button { showPicker.toggle() } label: {
                        Text(hasAlarm ? fmt(pendingAlarm) : "Alarm")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.theme.accent2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(hasAlarm ? theme.theme.accent2.opacity(0.2) : theme.theme.accent2.opacity(0.08))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.theme.accent2.opacity(hasAlarm ? 0.6 : 0.2), lineWidth: 1))
                    }

                    Button(action: addTask) {
                        Text("ADD")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "060a0f"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(theme.theme.accent)
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
                                    .foregroundColor(theme.theme.accent)
                                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    .background(theme.theme.accent.opacity(0.12)).cornerRadius(7)
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
            } // VStack
            // Theme modal overlay
            if showThemePicker {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showThemePicker = false } }
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 12) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 36, height: 4)
                                .padding(.top, 12)
                            Text("SELECT THEME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.theme.accent.opacity(0.6))
                                .tracking(3)
                            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                            LazyVGrid(columns: cols, spacing: 8) {
                                Button {
                                    theme.setManual(nil)
                                    withAnimation { showThemePicker = false }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "wand.and.stars").font(.system(size: 18))
                                        Text("Auto").font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    }
                                    .foregroundColor(theme.manualTheme == nil ? Color(hex: "060a0f") : theme.theme.accent)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(theme.manualTheme == nil ? theme.theme.accent : theme.theme.accent.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.theme.accent.opacity(0.3), lineWidth: 1))
                                }
                                ForEach(ThemeManager.manualOptions, id: \.0) { id, emoji, name in
                                    Button {
                                        theme.setManual(id)
                                        withAnimation { showThemePicker = false }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(emoji).font(.system(size: 18))
                                            Text(name)
                                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                .lineLimit(1).minimumScaleFactor(0.7)
                                        }
                                        .foregroundColor(theme.manualTheme == id ? Color(hex: "060a0f") : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(theme.manualTheme == id ? theme.theme.accent : Color.white.opacity(0.06))
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                            theme.manualTheme == id ? theme.theme.accent : Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "0a1020").opacity(0.97))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.theme.accent.opacity(0.15), lineWidth: 1))
                        )
                    }
                }
                .transition(.opacity)
            }
        } // ZStack
        }
    }

    func previewSound(_ sound: AlarmSound) {
        previewPlayer?.stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        if let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: sound.path)) {
            player.volume = 1.0
            player.play()
            previewPlayer = player
        } else {
            AudioServicesPlaySystemSound(1304)
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
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(theme.theme.accent.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if task.done {
                        Circle().fill(theme.theme.accent.opacity(0.2)).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(theme.theme.accent)
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
                            .foregroundColor(theme.theme.accent2)
                        Text(alarm)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(theme.theme.accent2)
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
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(theme.theme.accent.opacity(pulse ? 0.08 : 0.45), lineWidth: pulse ? 32 : 2)
                        .frame(width: 100, height: 100)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    Circle().fill(theme.theme.accent.opacity(0.12)).frame(width: 80, height: 80)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 34))
                        .foregroundColor(theme.theme.accent)
                }
                .padding(.top, 36)
                .padding(.bottom, 20)
                .onAppear { pulse = true }

                Text("ALARM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.theme.accent.opacity(0.5))
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
                        .foregroundColor(theme.theme.accent)
                        .padding(.bottom, 32)
                }

                Button {
                    AlarmManager.shared.stopAlarm()
                    onDismiss()
                } label: {
                    Text("DISMISS")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "060a0f"))
                        .frame(width: 200, height: 50)
                        .background(theme.theme.accent)
                        .cornerRadius(25)
                }
                .padding(.bottom, 40)
            }
            .frame(width: 320)
            .background(Color(hex: "0c1a1a"))
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.theme.accent.opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - Panel View
struct PanelView<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder let content: () -> Content
    @StateObject private var themeMgr = ThemeManager.shared

    var effectiveAccent: Color { accent ?? themeMgr.theme.accent }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(effectiveAccent.opacity(0.22), lineWidth: 1))
            GeometryReader { g in
                LinearGradient(colors: [.clear, effectiveAccent, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.7, height: 1)
                    .position(x: g.size.width / 2, y: 0)
                    .opacity(0.5)
                content()
                    .padding(12)
                    .frame(width: g.size.width, height: g.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 2), value: effectiveAccent.description)
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
