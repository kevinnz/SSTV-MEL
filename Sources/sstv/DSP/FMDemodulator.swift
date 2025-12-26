import Foundation

/// FM Demodulator using analytic signal (Hilbert transform) approach
///
/// SSTV transmits image data as FM-modulated audio:
/// - Black = 1500 Hz
/// - White = 2300 Hz
/// - Sync = 1200 Hz
///
/// The correct way to decode this is FM demodulation:
/// 1. Convert real signal to analytic (complex) signal using Hilbert transform
/// 2. Compute instantaneous phase: φ(t) = atan2(imag, real)
/// 3. Compute instantaneous frequency: f(t) = dφ/dt / (2π)
///
/// This provides continuous frequency tracking with sample-level precision,
/// unlike Goertzel which bins frequencies at fixed intervals.
struct FMDemodulator {
    let sampleRate: Double
    
    /// Hilbert transform FIR filter coefficients
    /// Using a 65-tap filter for good frequency response
    private static let hilbertTaps = 65
    private static let hilbertCoeffs: [Double] = {
        var coeffs = [Double](repeating: 0.0, count: hilbertTaps)
        let center = hilbertTaps / 2
        
        for i in 0..<hilbertTaps {
            let n = i - center
            if n == 0 {
                coeffs[i] = 0.0
            } else if n % 2 != 0 {
                // Hilbert transform: h[n] = 2/(πn) for odd n, 0 for even n
                coeffs[i] = 2.0 / (Double.pi * Double(n))
            } else {
                coeffs[i] = 0.0
            }
            
            // Apply Hamming window for better frequency response
            let window = 0.54 - 0.46 * cos(2.0 * Double.pi * Double(i) / Double(hilbertTaps - 1))
            coeffs[i] *= window
        }
        
        return coeffs
    }()
    
    /// Demodulate FM signal to instantaneous frequency
    ///
    /// - Parameter samples: Input audio samples (real-valued)
    /// - Returns: Array of instantaneous frequencies in Hz for each sample
    func demodulate(samples: [Double]) -> [Double] {
        let n = samples.count
        guard n > 2 else { return [] }
        
        // Step 1: Apply Hilbert transform to get quadrature component
        let hilbert = applyHilbertTransform(samples)
        
        // Now we have:
        // - I (in-phase) = original signal (delayed to align)
        // - Q (quadrature) = Hilbert transform of signal
        
        // Step 2: Compute instantaneous phase difference (FM discriminator)
        var frequencies = [Double](repeating: 0.0, count: n)
        let halfTaps = Self.hilbertTaps / 2
        
        // Delay the original signal to align with Hilbert output
        for i in (halfTaps + 1)..<(n - halfTaps) {
            let iCurrent = samples[i]
            let qCurrent = hilbert[i]
            let iPrev = samples[i - 1]
            let qPrev = hilbert[i - 1]
            
            // FM discriminator: multiply by conjugate of previous sample
            // (I + jQ) * (I_prev - jQ_prev) = (I*I_prev + Q*Q_prev) + j(Q*I_prev - I*Q_prev)
            let realPart = iCurrent * iPrev + qCurrent * qPrev
            let imagPart = qCurrent * iPrev - iCurrent * qPrev
            
            // Phase difference = atan2(imag, real)
            let phaseDiff = atan2(imagPart, realPart)
            
            // Convert phase difference to frequency
            // f = (dφ/dt) / (2π), and we're computing per-sample, so:
            // f = phaseDiff * sampleRate / (2π)
            frequencies[i] = phaseDiff * sampleRate / (2.0 * Double.pi)
        }
        
        // Shift frequency to match SSTV center frequency (1900 Hz)
        // The FM discriminator gives deviation from carrier
        // SSTV uses 1900 Hz as nominal center
        let centerFreq = 1900.0
        for i in 0..<n {
            frequencies[i] += centerFreq
        }
        
        // Fill in edges with nearest valid values
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
    
    /// Apply Hilbert transform using FIR filter
    private func applyHilbertTransform(_ samples: [Double]) -> [Double] {
        let n = samples.count
        var output = [Double](repeating: 0.0, count: n)
        let coeffs = Self.hilbertCoeffs
        let taps = Self.hilbertTaps
        let halfTaps = taps / 2
        
        // Convolve with Hilbert filter
        for i in halfTaps..<(n - halfTaps) {
            var sum = 0.0
            for j in 0..<taps {
                sum += samples[i - halfTaps + j] * coeffs[j]
            }
            output[i] = sum
        }
        
        return output
    }
}

/// High-performance frequency tracker using FM demodulation
///
/// This replaces the Goertzel-based FrequencyTracker with proper FM demodulation
/// for accurate SSTV decoding.
struct FMFrequencyTracker {
    let sampleRate: Double
    let demodulator: FMDemodulator
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.demodulator = FMDemodulator(sampleRate: sampleRate)
    }
    
    /// Track frequencies across the entire audio signal using FM demodulation
    ///
    /// - Parameter samples: Complete audio signal (mono)
    /// - Returns: Array of detected frequencies, one per sample
    func track(samples: [Double]) -> [Double] {
        print("  Using FM demodulation for frequency tracking...")
        
        let startTime = Date()
        
        // Demodulate entire signal at once
        let frequencies = demodulator.demodulate(samples: samples)
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("  FM demodulation complete in \(String(format: "%.1f", elapsed))s")
        print("  Detected \(frequencies.count) frequency measurements")
        
        return frequencies
    }
}
