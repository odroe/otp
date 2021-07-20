use criterion::{criterion_group, criterion_main, Criterion};
use ootp::totp::{CreateOption, Totp};

pub fn criterion_benchmark(c: &mut Criterion) {
    let totp = Totp::secret("A strong shared secret", CreateOption::Default);
    c.bench_function("TOTP Generation", |b| b.iter(|| totp.make()));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
