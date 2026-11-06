import Foundation
import ProductimerKit

extension AppModel {
    func seedStatisticsForQA(empty: Bool = false) {
        guard Store.isOverridden else { return }
        var seed = SavedTimer()
        if !empty {
            let calendar = Calendar.current
            for day in 0..<12 {
                let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0,
                    of: calendar.date(byAdding: .day, value: -day, to: .now)!)!
                for session in 0..<(day % 3 + 1) {
                    let date = morning.addingTimeInterval(Double(session) * 3600)
                    seed.toggle(at: date)
                    seed.tick(at: date.addingTimeInterval(1500), allowAutoStart: false)
                    seed.toggle(at: date.addingTimeInterval(1500))
                    seed.tick(at: date.addingTimeInterval(1800), allowAutoStart: false)
                    seed.resetCycle(at: date.addingTimeInterval(1800))
                }
            }
            let date = Date.now.addingTimeInterval(-120)
            seed.toggle(at: date)
            seed.skip(at: .now)
        }
        installQAHistory(seed)
    }
}
