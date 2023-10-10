## How to use
```bash
> pwd
~/.julia/dev/UnROOT/benchmark/ 

> julia --project=.
# ]instantiate
```
```julia
julia> using PkgBenchmark

julia> judge("UnROOT", "7f9eb14c270baefbc5b9da8d27530ac8b1a43975", "b59a632b835005ddc719a19211f99cf8f537114d")
PkgBenchmark: Running benchmarks...
PkgBenchmark: using benchmark tuning data in /home/akako/Documents/github/dotFiles/homedir/.julia/dev/UnROOT/benchmark/tune.json
(1/2) benchmarking "Latency"...
  (1/1) benchmarking "load"...
  done (took 1.501919237 seconds)
done (took 1.801246061 seconds)
(2/2) benchmarking "Performance"...
done (took 0.22250547 seconds)
Benchmarking 100%|███████████████████████████████████████████████████████████████████████████████████████████████████| Time: 0:00:03
PkgBenchmark: Running benchmarks...
PkgBenchmark: using benchmark tuning data in /home/akako/Documents/github/dotFiles/homedir/.julia/dev/UnROOT/benchmark/tune.json
(1/2) benchmarking "Latency"...
  (1/1) benchmarking "load"...
  done (took 71.740677984 seconds)
done (took 72.041515016 seconds)
(2/2) benchmarking "Performance"...
done (took 0.932772476 seconds)
Benchmarking 100%|███████████████████████████████████████████████████████████████████████████████████████████████████| Time: 0:01:14
Benchmarkjudgement (target / baseline):
    Package: UnROOT
    Dates: 10 Oct 2023 - 16:26 / 10 Oct 2023 - 16:27
    Package commits: 7f9eb1 / b59a63
    Julia commits: 404750 / 404750

julia> export_markdown(stdout, a)

```
# Benchmark Report for *UnROOT*

## Job Properties
* Time of benchmarks:
    - Target: 10 Oct 2023 - 16:26
    - Baseline: 10 Oct 2023 - 16:27
* Package commits:
    - Target: 7f9eb1
    - Baseline: b59a63
* Julia commits:
    - Target: 404750
    - Baseline: 404750
* Julia command flags:
    - Target: None
    - Baseline: None
* Environment variables:
    - Target: None
    - Baseline: None

## Results
A ratio greater than `1.0` denotes a possible regression (marked with :x:), while a ratio less
than `1.0` denotes a possible improvement (marked with :white_check_mark:). Only significant results - results
that indicate possible regressions or improvements - are shown below (thus, an empty table means that all
benchmark results remained invariant between builds).

| ID                    | time ratio                   | memory ratio                 |
|-----------------------|------------------------------|------------------------------|
| `["Latency", "load"]` | 0.02 (5%) :white_check_mark: | 0.03 (1%) :white_check_mark: |

## Benchmark Group List
Here's a list of all the benchmark groups executed by this job:

- `["Latency"]`

## Julia versioninfo

### Target
```
Julia Version 1.10.0-beta3
Commit 404750f8586 (2023-10-03 12:53 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Linux (x86_64-linux-gnu)
      "Arch Linux"
  uname: Linux 6.5.6-arch2-1 #1 SMP PREEMPT_DYNAMIC Sat, 07 Oct 2023 08:14:55 +0000 x86_64 unknown
  CPU: 11th Gen Intel(R) Core(TM) i5-1135G7 @ 2.40GHz:
              speed         user         nice          sys         idle          irq
       #1  4200 MHz      29066 s        188 s       9190 s     677716 s      18974 s
       #2   400 MHz      41019 s        140 s       9512 s     132804 s       1987 s
       #3  3673 MHz      43002 s         81 s      10631 s     134068 s       2328 s
       #4  4008 MHz      42636 s        101 s       9387 s     135917 s       1926 s
       #5  4126 MHz      39448 s        177 s      10145 s     137327 s       1887 s
       #6  1702 MHz      40164 s         90 s       9395 s     134924 s       2047 s
       #7   400 MHz      42627 s         46 s       9262 s     135075 s       1922 s
       #8   400 MHz      39661 s         48 s       9766 s     138049 s       1688 s
  Memory: 31.13873291015625 GB (19631.62109375 MB free)
  Uptime: 166684.1 sec
  Load Avg:  1.16  0.83  1.0
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-15.0.7 (ORCJIT, tigerlake)
  Threads: 5 on 8 virtual cores
```

### Baseline
```
Julia Version 1.10.0-beta3
Commit 404750f8586 (2023-10-03 12:53 UTC)
Build Info:
  Official https://julialang.org/ release
Platform Info:
  OS: Linux (x86_64-linux-gnu)
      "Arch Linux"
  uname: Linux 6.5.6-arch2-1 #1 SMP PREEMPT_DYNAMIC Sat, 07 Oct 2023 08:14:55 +0000 x86_64 unknown
  CPU: 11th Gen Intel(R) Core(TM) i5-1135G7 @ 2.40GHz:
              speed         user         nice          sys         idle          irq
       #1  3505 MHz      29286 s        188 s       9210 s     678335 s      18978 s
       #2  3818 MHz      41184 s        140 s       9524 s     133493 s       1989 s
       #3  3257 MHz      43265 s         81 s      10650 s     134656 s       2328 s
       #4   400 MHz      42722 s        101 s       9397 s     136687 s       1928 s
       #5   400 MHz      39713 s        177 s      10163 s     137913 s       1888 s
       #6  4200 MHz      40239 s         90 s       9405 s     135705 s       2048 s
       #7   400 MHz      42714 s         46 s       9271 s     135848 s       1923 s
       #8  1574 MHz      39707 s         48 s       9777 s     138858 s       1689 s
  Memory: 31.13873291015625 GB (19578.73828125 MB free)
  Uptime: 166771.41 sec
  Load Avg:  1.46  1.04  1.06
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-15.0.7 (ORCJIT, tigerlake)
  Threads: 5 on 8 virtual cores
```


