import Foundation
import CoreAudio

final class GainState {
    private let lock = NSLock()
    private var target: Float = 1
    func set(_ value: Float) { lock.lock(); target = value; lock.unlock() }
    func get() -> Float { lock.lock(); defer { lock.unlock() }; return target }
}

final class AudioRoute {
    let device: OutputDevice
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private let gain: GainState
    private var previous: Float
    private var sumIn: Double = 0
    private var sumOut: Double = 0
    private var samples: Int = 0
    private var lastLog = ProcessInfo.processInfo.systemUptime
    private let debug = ProcessInfo.processInfo.environment["INZONE_DEBUG"] == "1"

    init(device: OutputDevice, gain: GainState, ownProcess: AudioObjectID) throws {
        self.device = device; self.gain = gain; self.previous = gain.get()
        let description = CATapDescription()
        description.name = "InzoneVolume \(device.name)"
        description.uuid = UUID()
        description.isPrivate = true
        description.isExclusive = true
        description.deviceUID = device.uid
        description.setValue(0, forKey: "stream")
        description.setValue([NSNumber(value: ownProcess)], forKey: "processes")
        description.muteBehavior = .mutedWhenTapped
        var status = AudioHardwareCreateProcessTap(description, &tap)
        guard status == noErr else { throw RouteError("오디오 탭 생성", status) }
        do {
            let aggregateUID = "com.wak.InzoneVolume.\(UUID().uuidString)"
            let spec: [String: Any] = [
                kAudioAggregateDeviceNameKey: "InzoneVolume \(device.name)",
                kAudioAggregateDeviceUIDKey: aggregateUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceMainSubDeviceKey: device.uid,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: device.uid]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]],
                kAudioAggregateDeviceTapAutoStartKey: true
            ]
            status = AudioHardwareCreateAggregateDevice(spec as CFDictionary, &aggregate)
            guard status == noErr else { throw RouteError("오디오 장치 생성", status) }
            var format = AudioStreamBasicDescription()
            var address = AudioDevices.address(kAudioTapPropertyFormat)
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            status = AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format)
            guard status == noErr, format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32 else {
                throw RouteError("지원하지 않는 오디오 형식", status)
            }
            status = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregate, nil) { [weak self] _, input, _, output, _ in
                self?.process(input: input, output: output)
            }
            guard status == noErr, let ioProc else { throw RouteError("오디오 콜백 생성", status) }
            status = AudioDeviceStart(aggregate, ioProc)
            guard status == noErr else { throw RouteError("시스템 오디오 캡처 시작 (권한 확인)", status) }
        } catch { close(); throw error }
    }
    private func process(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outs = UnsafeMutableAudioBufferListPointer(output)
        let next = gain.get()
        let frameCount = outs.first.map { Int($0.mDataByteSize) / (MemoryLayout<Float>.size * max(1, Int($0.mNumberChannels))) } ?? 0
        for (index, out) in outs.enumerated() {
            guard let dst = out.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let count = Int(out.mDataByteSize) / MemoryLayout<Float>.size
            guard index < ins.count, let src = ins[index].mData?.assumingMemoryBound(to: Float.self) else {
                dst.initialize(repeating: 0, count: count); continue
            }
            let available = min(count, Int(ins[index].mDataByteSize) / MemoryLayout<Float>.size)
            let channels = max(1, Int(out.mNumberChannels))
            for i in 0..<available {
                let fraction = frameCount > 1 ? Float(i / channels) / Float(frameCount - 1) : 1
                let value = src[i] * (previous + (next - previous) * fraction)
                dst[i] = value
                if debug { sumIn += Double(src[i] * src[i]); sumOut += Double(value * value) }
            }
            if available < count { dst.advanced(by: available).initialize(repeating: 0, count: count - available) }
            if debug { samples += available }
        }
        previous = next
        if debug && ProcessInfo.processInfo.systemUptime - lastLog >= 1 && samples > 0 {
            let inputRMS = sqrt(sumIn / Double(samples)); let outputRMS = sqrt(sumOut / Double(samples))
            let name = device.name
            DispatchQueue.global(qos: .utility).async { NSLog("INZONE_DEBUG %@ input RMS=%.6f output RMS=%.6f ratio=%.4f", name, inputRMS, outputRMS, inputRMS > 0 ? outputRMS / inputRMS : 0) }
            sumIn = 0; sumOut = 0; samples = 0; lastLog = ProcessInfo.processInfo.systemUptime
        }
    }
    func close() {
        if aggregate != 0 {
            if let ioProc { AudioDeviceStop(aggregate, ioProc); AudioDeviceDestroyIOProcID(aggregate, ioProc); self.ioProc = nil }
            AudioHardwareDestroyAggregateDevice(aggregate); aggregate = 0
        }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }
    deinit { close() }
}

struct RouteError: LocalizedError {
    let operation: String
    let status: OSStatus
    init(_ operation: String, _ status: OSStatus) { self.operation = operation; self.status = status }
    var errorDescription: String? { "\(operation) 실패 (\(status))" }
}
