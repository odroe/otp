use criterion::{black_box, criterion_group, criterion_main, Criterion};
use ootp::hotp::{Hotp, MakeOption};

pub fn criterion_benchmark(c: &mut Criterion) {
    let hotp = Hotp::new("A strong shared secret");
    c.bench_function("HOTP Generation", |b| {
        b.iter(|| hotp.make(black_box(MakeOption::Default)))
    });
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
