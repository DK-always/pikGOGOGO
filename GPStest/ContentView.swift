import SwiftUI
import CoreLocation
import Combine
import UIKit

// MARK: - 輔助元件：目標按鈕
struct TargetButton: View {
    let title: String?
    let value: Int?
    let isSelected: Bool
    let action: () -> Void
    
    init(value: Int?, isSelected: Bool, action: @escaping () -> Void) {
        self.value = value
        self.title = nil
        self.isSelected = isSelected
        self.action = action
    }
    
    init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.value = nil
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title ?? (value == nil ? "∞" : "\(value!)"))
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color.blue : Color.white)
                .foregroundColor(isSelected ? .white : .blue)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 3)
        }
    }
}

// MARK: - 主畫面視圖
struct ContentView: View {
    @StateObject private var locationModel = LocationViewModel()
    @StateObject private var healthManager = HealthManager()
    
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // 目標步數預設選項
    let defaultOptions = [100, 1000, 3000, 5000, 10000]
    
    @State private var showCustomSheet = false
    @State private var customInputValue = ""
    @FocusState private var isInputFocused: Bool
    
    var isCustomTarget: Bool {
        guard let target = healthManager.selectedTarget else { return false }
        return !defaultOptions.contains(target)
    }
    
    // 顏色定義
    let colorTotal = Color(red: 0x80 / 255.0, green: 0x00 / 255.0, blue: 0x80 / 255.0)
    let colorLap = Color(red: 0x94 / 255.0, green: 0x00 / 255.0, blue: 0xD3 / 255.0)

    var body: some View {
        VStack(spacing: 15) {
            
            // 頂部狀態列
            HStack {
                Image(systemName: healthManager.isWalking ? "figure.walk" : "figure.stand")
                    .foregroundColor(healthManager.isWalking ? .green : .gray)
                    .symbolEffect(.bounce, value: healthManager.isWalking)
                Text(healthManager.isWalking ? "模擬散步中..." : "準備散步")
                    .font(.headline)
                    .foregroundColor(healthManager.isWalking ? .green : .gray)
            }
            .padding(.top)

            // MARK: - 1. 今日累積步數卡片
            VStack(spacing: 5) {
                Text("今日累積步數")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
               
                HStack(alignment: .bottom) {
                    Text("\(Int(healthManager.todayTotalSteps))")
                        .font(.system(size: 45, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    Text("步")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(colorTotal)
            .cornerRadius(16)
            .shadow(color: colorTotal.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.horizontal)

            // MARK: - 2. 區間計步卡片
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("區間計步")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(alignment: .bottom) {
                        Text("\(Int(healthManager.lapSteps))")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        if let target = healthManager.selectedTarget {
                            let effectiveTarget = Int(Double(target) * min(healthManager.targetMultiplier, 1.0))
                            
                            Text("/ \(effectiveTarget)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.bottom, 6)
                        } else {
                            Text("步")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.bottom, 6)
                        }
                    }
                }
               
                Spacer()
               
                // 歸零按鈕
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    healthManager.resetLap()
                }) {
                    VStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("歸零")
                            .font(.caption2)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
            }
            .padding()
            .background(colorLap)
            .cornerRadius(16)
            .shadow(color: colorLap.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.horizontal)

            // MARK: - 3. 設定自動停止目標
            VStack(alignment: .leading, spacing: 10) {
                Text("設定自動停止目標")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 10) {
                    TargetButton(value: nil, isSelected: healthManager.selectedTarget == nil) { healthManager.selectedTarget = nil }
                    TargetButton(value: 100, isSelected: healthManager.selectedTarget == 100) { healthManager.selectedTarget = 100 }
                    // MARK: 修正處 - 這裡必須設為 true
                    TargetButton(
                        title: isCustomTarget ? "\(healthManager.selectedTarget!)" : "自訂",
                        isSelected: isCustomTarget
                    ) {
                        customInputValue = ""
                        showCustomSheet = true // ✅ 確保這裡是 true
                    }
                    TargetButton(value: 10000, isSelected: healthManager.selectedTarget == 10000) { healthManager.selectedTarget = 10000 }
                }
                .padding(.horizontal)
                
                HStack(spacing: 10) {
                    TargetButton(value: 1000, isSelected: healthManager.selectedTarget == 1000) { healthManager.selectedTarget = 1000 }
                    TargetButton(value: 3000, isSelected: healthManager.selectedTarget == 3000) { healthManager.selectedTarget = 3000 }
                    TargetButton(value: 5000, isSelected: healthManager.selectedTarget == 5000) { healthManager.selectedTarget = 5000 }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 5)

            // MARK: - 4. 目標達成百分比滑桿
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("目標達成百分比")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(min(Int(healthManager.targetMultiplier * 100), 100))%")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Slider(value: $healthManager.targetMultiplier, in: 0.05...1.01, step: 0.05)
                    .accentColor(.blue)
                    .padding(.horizontal)
                
                if let target = healthManager.selectedTarget {
                    let displayTarget = Int(Double(target) * min(healthManager.targetMultiplier, 1.0))
                    Text("系統將在累積 \(displayTarget) 步時自動停止")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.bottom, 5)
            
            // MARK: - 5. 控制按鈕
            Button(action: {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if healthManager.isWalking {
                    stopSimulation()
                } else {
                    startSimulation()
                }
            }) {
                Text(healthManager.isWalking ? "停止散步" : "開始散步")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(healthManager.isWalking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
            }
            .padding(.horizontal)
            
            Spacer()

            if !healthManager.isWalking {
                Text("提示：達到百分比目標將自動停止，數據每日 0 點歸零")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        // 記憶體優化：使用 onChange 監聽狀態切換
        .onChange(of: healthManager.isWalking) { oldValue, newValue in
            if !newValue && backgroundTaskID != .invalid {
                endBackgroundTask()
            }
        }
        // MARK: - 自訂目標 Sheet
        .sheet(isPresented: $showCustomSheet) {
            VStack(spacing: 20) {
                Text("輸入目標步數")
                    .font(.headline)
                    .padding(.top)
                
                TextField("例如：8888", text: $customInputValue)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($isInputFocused)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button("取消") {
                        showCustomSheet = false
                    }
                    .foregroundColor(.gray)
                    
                    Button("確定設定") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if let value = Int(customInputValue), value > 0 {
                            healthManager.selectedTarget = value
                        }
                        showCustomSheet = false
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                }
                .padding(.bottom)
            }
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        }
        .onAppear {
            healthManager.requestAuthorization()
        }
    }

    // MARK: - 記憶體友善的背景任務管理
    
    func startSimulation() {
        healthManager.resetLap()
        renewBackgroundTask()
        healthManager.startSimulation()
    }

    func stopSimulation() {
        healthManager.stopSimulation()
        endBackgroundTask()
    }

    func renewBackgroundTask() {
        endBackgroundTask()
        // 修正處：無 weak self
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WalkingTask") {
            self.stopSimulation()
        }
    }

    func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}
