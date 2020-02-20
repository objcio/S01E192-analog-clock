//
//  ContentView.swift
//  StopwatchButtons
//
//  Created by Chris Eidhof on 14.11.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//

import SwiftUI

struct SizeKey: PreferenceKey {
    static let defaultValue: [CGSize] = []
    static func reduce(value: inout [CGSize], nextValue: () -> [CGSize]) {
        value.append(contentsOf: nextValue())
    }
}

struct ButtonCircle: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        let background = Circle()
            .fill()
            .overlay(
                Circle()
                    .fill(Color.white)
                    .opacity(isPressed ? 0.3 : 0)
            )
            .overlay(
                Circle()
                    .stroke(lineWidth: 2)
                    .foregroundColor(.white)
                    .padding(4)
            )
            
        let foreground = content
            .fixedSize()
            .padding(15)
            .equalSize()
            .foregroundColor(.white)
        return foreground
            .background(background)
    }
}

struct SizeEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}

extension EnvironmentValues {
    var size: CGSize? {
        get { self[SizeEnvironmentKey.self] }
        set { self[SizeEnvironmentKey.self] = newValue }
    }
}

fileprivate struct EqualSize: ViewModifier {
    @Environment(\.size) private var size
    
    func body(content: Content) -> some View {
        content.overlay(GeometryReader { proxy in
            Color.clear.preference(key: SizeKey.self, value: [proxy.size])
        })
        .frame(width: size?.width, height: size?.width)
    }
}

fileprivate struct EqualSizes: ViewModifier {
    @State var width: CGFloat?
    func body(content: Content) -> some View {
        content.onPreferenceChange(SizeKey.self, perform: { sizes in
            self.width = sizes.map { $0.width }.max()
        }).environment(\.size, width.map { CGSize(width: $0, height: $0) })
    }
}

extension View {
    func equalSize() -> some View {
        self.modifier(EqualSize())
    }
    
    func equalSizes() -> some View {
        self.modifier(EqualSizes())
    }
}

struct CircleStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.modifier(ButtonCircle(isPressed: configuration.isPressed))
    }
}

let formatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.minute, .second]
    f.zeroFormattingBehavior = .pad
    return f
}()
let numberFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    f.maximumIntegerDigits  = 0
    f.alwaysShowsDecimalSeparator = true
    return f
}()

extension TimeInterval {
    var formatted: String {
        let ms = self.truncatingRemainder(dividingBy: 1)
        return formatter.string(from: self)! + numberFormatter.string(from: NSNumber(value: ms))!
    }
}

extension View {
    func visible(_ v: Bool) -> some View {
        self.opacity(v ? 1 : 0)
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    init(center: CGPoint, radius: CGFloat) {
        self = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

struct Pointer: Shape {
    var circleRadius: CGFloat = 3
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.midY - circleRadius))
            p.addEllipse(in: CGRect(center: rect.center, radius: circleRadius))
            p.move(to: CGPoint(x: rect.midX, y: rect.midY + circleRadius))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.midY + rect.height / 5))
        }
    }
}

struct Clock: View {
    var time: TimeInterval = 10
    var lapTime: TimeInterval?

    func tick(at tick: Int) -> some View {
            VStack {
                Rectangle()
                    .fill(Color.primary)
                    .opacity(tick % 20 == 0 ? 1 : 0.4)
                    .frame(width: 2, height: tick % 4 == 0 ? 15 : 7)
                Spacer()
        }.rotationEffect(Angle.degrees(Double(tick)/240 * 360))
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<60*4) { tick in
                self.tick(at: tick)
            }
            if lapTime != nil {
                Pointer()
                    .stroke(Color.blue, lineWidth: 2)
                    .rotationEffect(Angle.degrees(Double(lapTime!) * 360/60))
            }
            Pointer()
                .stroke(Color.orange, lineWidth: 2)
                .rotationEffect(Angle.degrees(Double(time) * 360/60))
            Color.clear
        }
    }
}


struct ClockView_Previews: PreviewProvider {
    static var previews: some View {
        Clock()
            .background(Color.white)
            .previewLayout(.fixed(width: 300, height: 300))
    }
}

struct ContentView: View {
    @ObservedObject var stopwatch = Stopwatch()
    
    var body: some View {
        VStack {
            Clock(time: stopwatch.total, lapTime: stopwatch.laps.last?.0)
//            Text(stopwatch.total.formatted)
//                .font(Font.system(size: 64, weight: .thin).monospacedDigit())
            HStack {
                ZStack {
                    Button(action: { self.stopwatch.lap() }) {
                        Text("Lap")
                    }
                    .foregroundColor(.gray)
                    .visible(stopwatch.isRunning)
                    Button(action: { self.stopwatch.reset() }) {
                        Text("Reset")
                    }
                    .foregroundColor(.gray)
                    .visible(!stopwatch.isRunning)
                }
                Spacer()
                ZStack {
                    Button(action: { self.stopwatch.stop() }) {
                        Text("Stop")
                    }
                    .foregroundColor(.red)
                    .visible(stopwatch.isRunning)
                    Button(action: { self.stopwatch.start() }) {
                        Text("Start")
                    }
                    .foregroundColor(.green)
                    .visible(!stopwatch.isRunning)
                }
            }
            .padding(.horizontal)
            .equalSizes()
            .padding()
            .buttonStyle(CircleStyle())
            List {
                ForEach(stopwatch.laps.enumerated().reversed(), id: \.offset) { value in
                    HStack {
                        Text("Lap \(value.offset + 1)")
                        Spacer()
                        Text(value.element.0.formatted)
                            .font(Font.body.monospacedDigit())
                    }.foregroundColor(value.element.1.color)
                }
            }
        }
    }
}

extension LapType {
    var color: Color {
        switch self {
        case .regular:
            return .black
        case .shortest:
            return .green
        case .longest:
            return .red
        }
    }
}

final class Stopwatch: ObservableObject {
    @Published private var data = StopwatchData()
    private var timer: Timer?
    
    var total: TimeInterval {
        data.totalTime
    }
    
    var isRunning: Bool {
        data.absoluteStartTime != nil
    }
    
    var laps: [(TimeInterval, LapType)] { data.laps }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [unowned self] timer in
            self.data.currentTime = Date().timeIntervalSinceReferenceDate
        })
        data.start(at: Date().timeIntervalSinceReferenceDate)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        data.stop()
    }
    
    func reset() {
        stop()
        data = StopwatchData()
    }
    
    func lap() {
        data.lap()
    }
    
    deinit {
        stop()
    }
}

enum LapType {
    case regular
    case shortest
    case longest
}

struct StopwatchData {
    var absoluteStartTime: TimeInterval?
    var currentTime: TimeInterval = 0
    var additionalTime: TimeInterval = 0
    var lastLapEnd: TimeInterval = 0
    var _laps: [(TimeInterval, LapType)] = []
    
    var laps: [(TimeInterval, LapType)] {
        guard totalTime > 0 else { return [] }
        return _laps + [(currentLapTime, .regular)]
    }
    
    var currentLapTime: TimeInterval {
        totalTime - lastLapEnd
    }
    
    var totalTime: TimeInterval {
        guard let start = absoluteStartTime else { return additionalTime }
        return additionalTime + currentTime - start
    }
    
    mutating func start(at time: TimeInterval) {
        currentTime = time
        absoluteStartTime = time
    }
    
    mutating func stop() {
        additionalTime = totalTime
        absoluteStartTime = nil
    }
    
    mutating func lap() {
        let lapTimes = _laps.map { $0.0 } + [currentLapTime]
        if let shortest = lapTimes.min(), let longest = lapTimes.max(), shortest != longest {
            _laps = lapTimes.map { ($0, $0 == shortest ? .shortest : ($0 == longest ? .longest : .regular ))}
        } else {
            _laps = lapTimes.map { ($0, .regular) }
        }
        lastLapEnd = totalTime
    }
}
