import Foundation
import Accelerate

/// Quadrature FM Demodulator for SSTV
///
/// Implements the ADR-001 specified demodulation pipeline:
/// 1. Quadrature mixing to I/Q baseband (mix with 1900 Hz complex oscillator)
/// 2. FIR low-pass filtering (linear phase)
/// 3. Phase-difference FM demodulation
/// 4. Frequency output
///
/// SSTV transmits image data as FM-modulated audio:
/// - Black = 1500 Hz (deviation = -400 Hz from center)
/// - White = 2300 Hz (deviation = +400 Hz from center)
/// - Sync = 1200 Hz (deviation = -700 Hz from center)
/// - Center frequency = 1900 Hz
struct FMDemodulator {
    let sampleRate: Double
    
    /// Center frequency for SSTV (midpoint of video range)
    let centerFrequency: Double = 1900.0
    
    /// Low-pass filter cutoff frequency (Hz)
    /// Must be wide enough to pass ±700 Hz deviation (sync to white)
    let filterCutoff: Double = 1000.0
    
    /// Low-pass FIR filter coefficients
    /// 127-tap filter for good stopband rejection
    private let filterTaps: Int = 127
    private var filterCoeffs: [Double] = []
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.filterCoeffs = Self.designLowPassFilter(
            cutoff: filterCutoff,
            sampleRate: sampleRate,
            taps: filterTaps
        )
    }
    
    /// Design a low-pass FIR filter using windowed sinc method
    ///
    /// - Parameters:
    ///   - cutoff: Cutoff frequency in Hz
    ///   - sampleRate: Sample rate in Hz
    ///   - taps: Number of filter taps (odd for linear phase)
    /// - Returns: Filter coefficients
    private static func designLowPassFilter(cutoff: Double, sampleRate: Double, taps: Int) -> [Double] {
        var coeffs = [Double](repeating: 0.0, count: taps)
        let center = taps / 2
        let normalizedCutoff = cutoff / sampleRate
        
        for i in 0..<taps {
            let n = i - center
            if n == 0 {
                // At center, sinc(0) = 1
                coeffs[i] = 2.0 * normalizedCutoff
            } else {
                // Sinc function: sin(2πfc·n) / (πn)
                let x = 2.0 * Double.pi * normalizedCutoff * Double(n)
                coeffs[i] = sin(x) / (Double.pi * Double(n))
            }
            
            // Apply Blackman window for excellent stopband rejection
            let windowArg = 2.0 * Double.pi * Double(i) / Double(taps - 1)
            let window = 0.42 - 0.5 * cos(windowArg) + 0.08 * cos(2.0 * windowArg)
            coeffs[i] *= window
        }
        
        // Normalize to unity gain at DC
        let sum = coeffs.reduce(0, +)
        if abs(sum) > 1e-10 {
            for i in 0..<taps {
                coeffs[i] /= sum
            }
        }
        
        return coeffs
    }
    
    /// Demodulate FM signal to instantaneous frequency using quadrature method
    ///
    /// Pipeline (per ADR-001):
    /// 1. Quadrature mixing: multiply by cos(2πf_c·t) and sin(2πf_c·t)
    /// 2. Low-pass filter the I and Q components
    /// 3. Compute phase: φ = atan2(Q, I)
    /// 4. Compute frequency from phase derivative: f = dφ/dt / (2π)
    ///
    /// - Parameter samples: Input audio samples (real-valued)
    /// - Returns: Array of instantaneous frequencies in Hz for each sample
    func demodulate(samples: [Double]) -> [Double] {
        let n = samples.count
        guard n > filterTaps else { return [Double](repeating: centerFrequency, count: n) }
        
        // Step 1: Quadrature mixing - generate I/Q baseband signals
        // I(t) = signal(t) × cos(2π·f_center·t)
        // Q(t) = signal(t) × sin(2π·f_center·t)
        var iComponent = [Double](repeating: 0.0, count: n)
        var qComponent = [Double](repeating: 0.0, count: n)
        
        let omega = 2.0 * Double.pi * centerFrequency / sampleRate
        
        // Use vDSP for efficient mixing
        for i in 0..<n {
            let phase = omega * Double(i)
            iComponent[i] = samples[i] * cos(phase)
            qComponent[i] = samples[i] * -sin(phase)  // Negative for proper rotation direction
        }
        
        // Step 2: Low-pass filter both I and Q to remove high-frequency mixing products
        let iFiltered = applyFIRFilter(iComponent)
        let qFiltered = applyFIRFilter(qComponent)
        
        // Step 3 & 4: Compute instantaneous frequency from phase derivative
        // Using the efficient formula: f = (I·dQ/dt - Q·dI/dt) / (I² + Q²) / (2π)
        // Or equivalently: phase difference between consecutive samples
        var frequencies = [Double](repeating: centerFrequency, count: n)
        
        let halfTaps = filterTaps / 2
        
        for i in (halfTaps + 1)..<(n - halfTaps) {
            let iCurr = iFiltered[i]
            let qCurr = qFiltered[i]
            let iPrev = iFiltered[i - 1]
            let qPrev = qFiltered[i - 1]
            
            // Cross-multiply discriminator: measures phase difference
            // discrim = I_prev·Q_curr - Q_prev·I_curr = |z|²·sin(Δφ) ≈ |z|²·Δφ for small Δφ
            // normalize = I_prev² + Q_prev² = |z|²
            let discriminator = iPrev * qCurr - qPrev * iCurr
            let normalizer = iPrev * iPrev + qPrev * qPrev
            
            // Avoid division by zero
            if normalizer > 1e-10 {
                // Phase difference in radians
                // For small angles, sin(Δφ) ≈ Δφ
                // For larger angles, use atan for accuracy
                let phaseDiff = atan2(discriminator, iPrev * iCurr + qPrev * qCurr)
                
                // Convert phase difference to frequency deviation
                // Δφ per sample → frequency = Δφ × sampleRate / (2π)
                let freqDeviation = phaseDiff * sampleRate / (2.0 * Double.pi)
                
                // Add back center frequency
                frequencies[i] = centerFrequency + freqDeviation
            }
        }
        
        // Fill edges with nearest valid values
        if n > halfTaps + 1 {
            let firstValid = frequencies[halfTaps + 1]
            for i in 0...halfTaps {
                frequencies[i] = firstValid
            }
            let lastValid = frequencies[n - halfTaps - 1]
            for i in (n - halfTaps)..<n {
                frequencies[i] = lastValid
            }
        }
        
        return frequencies
    }
    
    /// Apply FIR filter using convolution
    private func applyFIRFilter(_ samples: [Double]) -> [Double] {
        let n = samples.count
        var output = [Double](repeating: 0.0, count: n)
        let halfTaps = filterTaps / 2
        
        // Use vDSP_conv for efficient convolution if available
        // For now, use direct convolution
        for i in halfTaps..<(n - halfTaps) {
            var sum = 0.0
            for j in 0..<filterTaps {
                sum += samples[i - halfTaps + j] * filterCoeffs[j]
            }
            output[i] = sum
        }
        
        return output
    }
}

/// High-performance frequency tracker using quadrature FM demodulation
///
/// This implements the ADR-001 specified demodulation for SSTV decoding.
struct FMFrequencyTracker {
    let sampleRate: Double
    let demodulator: FMDemodulator
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.demodulator = FMDemodulator(sampleRate: sampleRate)
    }
    
    /// Track frequencies across the entire audio signal using quadrature FM demodulation
    ///
    /// - Parameter samples: Complete audio signal (mono)
    /// - Returns: Array of detected frequencies, one per sample
    func track(samples: [Double]) -> [Double] {
        print("  Using quadrature FM demodulation (ADR-001 compliant)...")
        print("  Center frequency: \(demodulator.centerFrequency) Hz")
        print("  Filter cutoff: \(demodulator.filterCutoff) Hz")
        
        let startTime = Date()
        
        // Demodulate entire signal
        let frequencies = demodulator.demodulate(samples: samples)
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("  FM demodulation complete in \(String(format: "%.1f", elapsed))s")
        print("  Detected \(frequencies.count) frequency measurements")
        
        return frequencies
    }
}
