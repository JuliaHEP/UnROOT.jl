all:
	julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.resolve()'
	julia --project=. make.jl

clean:
	rm -rf build/

preview:
	julia -e 'using LiveServer; serve(dir="build")'
