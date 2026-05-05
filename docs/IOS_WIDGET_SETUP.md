# Dozara iOS Widget Kurulumu

## Gereksinimler
- Mac bilgisayar (WidgetKit için)
- Xcode 14+

## iOS Widget Adımları

### 1. Widget Extension Oluştur
Xcode'da:
1. Projeyi aç (`ios/Runner.xcworkspace`)
2. File → New → Target
3. **Widget Extension** seç
4. Product name: `DozaraWidget`
5. Finish

### 2. SwiftUI Widget Kodu

`DozaraWidget.swift` dosyasına:

```swift
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DozaraEntry {
        DozaraEntry(date: Date(), nextDose: "--:--", medicineName: "İlaç", pendingCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DozaraEntry) -> ()) {
        let entry = DozaraEntry(date: Date(), nextDose: "08:00", medicineName: "Parol", pendingCount: 3)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DozaraEntry>) -> ()) {
        // Shared App Group'dan veri oku
        let defaults = UserDefaults(suiteName: "group.com.dozara.app")
        let nextDose = defaults?.string(forKey: "next_dose") ?? "--:--"
        let medicineName = defaults?.string(forKey: "medicine_name") ?? "İlaç"
        let pendingCount = defaults?.string(forKey: "pending_count") ?? "0"
        
        let entry = DozaraEntry(
            date: Date(),
            nextDose: nextDose,
            medicineName: medicineName,
            pendingCount: Int(pendingCount) ?? 0
        )
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DozaraEntry: TimelineEntry {
    let date: Date
    let nextDose: String
    let medicineName: String
    let pendingCount: Int
}

struct DozaraWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(.purple)
                Text("Dozara")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            Text("Sonraki: \(entry.nextDose)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(entry.medicineName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(entry.pendingCount) bekleyen")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct DozaraWidget: Widget {
    let kind: String = "DozaraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DozaraWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dozara")
        .description("İlaç hatırlatıcınızı görün")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### 3. App Group Ekle
1. Xcode → Runner → Signing & Capabilities
2. **App Groups** ekle
3. Group ID: `group.com.dozara.app`

### 4. Info.plist Güncelle
`Info.plist`'e ekle:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 5. Build Et
```bash
flutter build ios
```

## Notlar
- Widget güncellemesi için Flutter tarafında `WidgetService.updateWidget()` çağrılmalı
- Veriler `home_widget` paketi ile SharedPreferences'a yazılıyor
- iOS Widget, Shared App Group'dan veri okuyor
