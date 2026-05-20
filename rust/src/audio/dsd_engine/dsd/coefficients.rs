const PI: f64 = std::f64::consts::PI;

pub fn generate_lowpass_fir(num_taps: usize, input_rate: u32, output_rate: u32) -> Vec<f64> {
    let cutoff = (output_rate as f64 / 2.0) / input_rate as f64;
    let cutoff = cutoff.min(0.98);
    generate_sinc_filter(num_taps, cutoff, WindowFunction::Blackman)
}

pub fn generate_sinc_filter(
    num_taps: usize,
    normalized_cutoff: f64,
    window: WindowFunction,
) -> Vec<f64> {
    let mut coeffs = Vec::with_capacity(num_taps);
    let center = (num_taps - 1) as f64 / 2.0;

    for i in 0..num_taps {
        let x = i as f64 - center;
        let sinc = if x.abs() < 1e-10 {
            1.0
        } else {
            (PI * normalized_cutoff * x).sin() / (PI * x)
        };
        let w = apply_window(i, num_taps, &window);
        coeffs.push(normalized_cutoff * sinc * w);
    }

    let sum: f64 = coeffs.iter().sum();
    if sum.abs() > 1e-10 {
        for c in coeffs.iter_mut() {
            *c /= sum;
        }
    }

    coeffs
}

#[derive(Clone, Copy)]
pub enum WindowFunction {
    Blackman,
    Hamming,
    Kaiser { beta: f64 },
}

fn apply_window(index: usize, size: usize, window: &WindowFunction) -> f64 {
    let n = index as f64 / (size - 1) as f64;
    match window {
        WindowFunction::Blackman => {
            0.42 - 0.5 * (2.0 * PI * n).cos() + 0.08 * (4.0 * PI * n).cos()
        }
        WindowFunction::Hamming => 0.54 - 0.46 * (2.0 * PI * n).cos(),
        WindowFunction::Kaiser { beta } => {
            let alpha = (size as f64 - 1.0) / 2.0;
            let x = (index as f64 - alpha) / alpha;
            bessel_i0(*beta * (1.0 - x * x).sqrt()) / bessel_i0(*beta)
        }
    }
}

fn bessel_i0(x: f64) -> f64 {
    let mut sum = 1.0;
    let mut term = 1.0;
    for k in 1..25 {
        term *= (x / (2.0 * k as f64)).powi(2);
        sum += term;
        if term < 1e-12 {
            break;
        }
    }
    sum
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_filter_generation() {
        let coeffs = generate_lowpass_fir(64, 352_800, 88_200);
        assert_eq!(coeffs.len(), 64);
        let sum: f64 = coeffs.iter().sum();
        assert!((sum - 1.0).abs() < 0.01, "Filter sum should be ~1.0, got {}", sum);
    }

    #[test]
    fn test_sinc_at_center() {
        let coeffs = generate_sinc_filter(33, 0.25, WindowFunction::Blackman);
        let center = coeffs[16];
        assert!(center > 0.0, "Center coefficient should be positive");
    }

    #[test]
    fn test_bessel_i0() {
        let val = bessel_i0(0.0);
        assert!((val - 1.0).abs() < 1e-10);
        let val = bessel_i0(5.0);
        assert!(val > 1.0, "I0(5) should be > 1, got {}", val);
    }
}
