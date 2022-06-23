# Contribute to UnROOT.jl

To make your first PR to this repo:

1. Have basic understanding of **Git**. The tutorial [Making a first Julia pull request](https://kshyatt.github.io/post/firstjuliapr/) could be helpful for learning both git and how to contribute to the Julia language projects.
2. Set up your local environment. We recommend use `Revise.jl` workflow.
3. Familiarise yourself with the source code. See [Source code organization](#source-code-organization).
4. Make changes & test them & submit PR.

## Contribution example ideas

### Core functionality
1. Parsing more ROOT types
2. Implement writing `.root` files

#### Help Wanted Issues
One of the best ways to contribute is by looking at issues labelled [help wanted](https://github.com/JuliaHEP/UnROOT.jl/labels/help%20wanted). These issues are not always beginner-friendly. However, you are welcome to [ask clarifying questions](#get-help) or just browse 
help wanted issues to see if there is anything that seems interesting to help with.

### Write tutorials
We can always use more tutorial on how to use UnROOT.jl efficiently and with other visualization or statistics tools in Julia for doing
HEP.

## Contribution guidelines
- We use the GitHub issue page for any bug filing or feature request, feel free to use them.
- For usage related discussion, feel free to use [HEP tag on Julia discourse](https://discourse.julialang.org/tag/hep) or join
our [mailist](https://groups.google.com/g/julia-hep).

### source code organization

The following table shows how the Flux code is organized:

| Directory  | Contents |
| ------------- | ------------- |
| docs  | Documentation|
| paper  | JOSS paper |
| src    |  Source code |
| test   |  Test suites  |
| test/samples   |  .root files for tests |
