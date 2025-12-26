import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

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
    
    #if canImport(Accelerate)
    /// Reversed filter coefficients for vDSP_conv (computed once at initialization)
    private var reversedFilterCoeffs: [Double] = []
    #endif
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.filterCoeffs = Self.designLowPassFilter(
            cutoff: filterCutoff,
            sampleRate: sampleRate,
            taps: filterTaps
        )
        #if canImport(Accelerate)
        // Pre-compute reversed coefficients for vDSP_conv
        self.reversedFilterCoeffs = Array(filterCoeffs.reversed())
        #endif
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
    /// - Parameters:
    ///   - samples: Input audio samples (real-valued)
    ///   - progressHandler: Optional callback for progress updates (0.0...1.0)
    /// - Returns: Array of instantaneous frequencies in Hz for each sample
    func demodulate(samples: [Double], progressHandler: ((Double) -> Void)? = nil) -> [Double] {
        let n = samples.count
        guard n > filterTaps else { return [Double](repeating: centerFrequency, count: n) }
        
        // Step 1: Quadrature mixing - generate I/Q baseband signals
        // I(t) = signal(t) × cos(2π·f_center·t)
        // Q(t) = signal(t) × sin(2π·f_center·t)
        var iComponent = [Double](repeating: 0.0, count: n)
        var qComponent = [Double](repeating: 0.0, count: n)
        
        var omega = 2.0 * Double.pi * centerFrequency / sampleRate
        
        #if canImport(Accelerate)
        // Use Accelerate framework for efficient vectorized operations on Apple platforms
        // 1. Generate phase ramp
        var phases = [Double](repeating: 0.0, count: n)
        var phaseValue = 0.0
        vDSP_vrampD(&phaseValue, &omega, &phases, 1, vDSP_Length(n))
        
        // 2. Compute sin/cos tables using Accelerate
        var cosValues = [Double](repeating: 0.0, count: n)
        var sinValues = [Double](repeating: 0.0, count: n)
        var count32 = Int32(n)
        
        vvcos(&cosValues, phases, &count32)
        vvsin(&sinValues, phases, &count32)
        
        // 3. Multiply with input samples to get I/Q components
        // I(t) = signal(t) × cos(phase)
        vDSP_vmulD(samples, 1,
                   cosValues, 1,
                   &iComponent, 1,
                   vDSP_Length(n))
        
        // Q(t) = signal(t) × -sin(phase)
        // Negative to form e^{-j·phase} = cos(phase) - j·sin(phase) for complex downconversion
        vDSP_vmulD(samples, 1,
                   sinValues, 1,
                   &qComponent, 1,
                   vDSP_Length(n))
        var minusOne: Double = -1.0
        vDSP_vsmulD(qComponent, 1,
                    &minusOne,
                    &qComponent, 1,
                    vDSP_Length(n))
        #else
        // Fallback implementation for non-Apple platforms
        for i in 0..<n {
            let phase = omega * Double(i)
            iComponent[i] = samples[i] * cos(phase)
            qComponent[i] = samples[i] * -sin(phase)  // Negative to form e^{-j·phase} for complex downconversion
        }
        #endif
        
        // Step 2: Low-pass filter both I and Q to remove high-frequency mixing products
        let iFiltered = applyFIRFilter(iComponent)
        let qFiltered = applyFIRFilter(qComponent)
        
        // Step 3 & 4: Compute instantaneous frequency from phase derivative
        // Using the efficient formula: f = (I·dQ/dt - Q·dI/dt) / (I² + Q²) / (2π)
        // Or equivalently: phase difference between consecutive samples
        var frequencies = [Double](repeating: centerFrequency, count: n)
        
        let halfTaps = filterTaps / 2
        let updateInterval = max(1, n / 100)  // Report every 1%
        
        for i in (halfTaps + 1)..<(n - halfTaps) {
            // Report progress periodically
            if updateInterval > 0 && i % updateInterval == 0 {
                let progress = Double(i) / Double(n)
                progressHandler?(progress)
            }
            
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
        
        #if canImport(Accelerate)
        // Use vDSP_conv for efficient convolution on Apple platforms
        // vDSP_conv performs: output[i] = Σ(signal[i+j] * filter[j])
        // Using pre-computed reversed filter coefficients
        
        // Convolve the entire signal with the filter
        vDSP_convD(samples, 1,
                   reversedFilterCoeffs, 1,
                   &output, 1,
                   vDSP_Length(n - filterTaps + 1),
                   vDSP_Length(filterTaps))
        
        // Shift the output to align with input (account for filter delay)
        // Move valid convolution results to the center without full array copy
        let validLength = n - filterTaps + 1
        if validLength > 0 && halfTaps > 0 {
            // Shift values in-place from end to beginning (backward iteration)
            // to avoid overwriting data that hasn't been moved yet
            for i in stride(from: validLength - 1, through: 0, by: -1) {
                output[i + halfTaps] = output[i]
            }
            // Zero out the beginning
            for i in 0..<halfTaps {
                output[i] = 0.0
            }
            // Zero out any remaining tail
            for i in (halfTaps + validLength)..<n {
                output[i] = 0.0
            }
        }
        #else
        // Fallback: direct convolution for non-Apple platforms
        for i in halfTaps..<(n - halfTaps) {
            var sum = 0.0
            for j in 0..<filterTaps {
                sum += samples[i - halfTaps + j] * filterCoeffs[j]
            }
            output[i] = sum
        }
        #endif
        
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
    /// - Parameters:
    ///   - samples: Complete audio signal (mono)
    ///   - progressHandler: Optional callback for progress updates (0.0...1.0)
    /// - Returns: Array of detected frequencies, one per sample
    func track(samples: [Double], progressHandler: ((Double) -> Void)? = nil) -> [Double] {
        // Report initial progress
        progressHandler?(0.0)
        
        // Demodulate entire signal
        let frequencies = demodulator.demodulate(samples: samples, progressHandler: progressHandler)
        
        // Report completion
        progressHandler?(1.0)
        
        return frequencies
    }
}
