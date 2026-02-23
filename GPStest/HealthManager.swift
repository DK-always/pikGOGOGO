import Foundation
import HealthKit
import Combine
import UIKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    
    @Published var todayTotalSteps: Double = 0
    @Published var lapSteps: Double = 0
    @Published var isWalking = false
    @Published var selectedTarget: Int? = nil
    @Published var targetMultiplier: Double = 1.0
    
    private var timer: Timer?

    init() {
        // ✅ 只在 App 剛開啟時，去資料庫抓「一次」今日總數據
        fetchTodayStepsFromHealthKit()
    }
    
    func fetchTodayStepsFromHealthKit() {
        guard let stepType = stepType else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else { return }
            let total = sum.doubleValue(for: HKUnit.count())
            DispatchQueue.main.async {
                self?.todayTotalSteps = total
            }
        }
        healthStore.execute(query)
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(), let stepType = stepType else { return }
        healthStore.requestAuthorization(toShare: [stepType], read: [stepType]) { [weak self] success, _ in
            if success { self?.fetchTodayStepsFromHealthKit() }
        }
    }
    
    func resetLap() {
        DispatchQueue.main.async { self.lapSteps = 0 }
    }
    
    func startSimulation() {
        if isWalking { return }
        isWalking = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 使用 RunLoop 確保背景 Timer 不會輕易失效
        let newTimer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }
    
    func stopSimulation() {
        DispatchQueue.main.async { [weak self] in
            self?.isWalking = false
            UIApplication.shared.isIdleTimerDisabled = false
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
    
    private func tick() {
        let randomSteps = Double.random(in: 15...25)
        addSimulatedSteps(count: randomSteps)
        
        let currentLap = self.lapSteps + randomSteps
        if let target = self.selectedTarget {
            let effectiveTarget = Double(target) * min(targetMultiplier, 1.0)
            if currentLap >= effectiveTarget {
                self.stopSimulation()
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
    
    private func addSimulatedSteps(count: Double) {
        // 使用 autoreleasepool 確保 HealthKit 物件立刻被系統回收
        autoreleasepool {
            guard count.isFinite && count > 0 && count < 2000, let stepType = stepType else { return }
            
            let now = Date()
            let startTime = now.addingTimeInterval(-5)
            let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: count)
            let sample = HKQuantitySample(type: stepType, quantity: quantity, start: startTime, end: now)
            
            healthStore.save(sample) { [weak self] success, _ in
                if success {
                    // ✅ 修正點：不再跟系統資料庫要資料，直接在本地端把步數加上去！
                    // 這樣既能同步顯示，又完全不會消耗記憶體和效能
                    DispatchQueue.main.async {
                        self?.todayTotalSteps += count
                        self?.lapSteps += count
                    }
                }
            }
        }
    }
}
