build:
	julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.resolve()'

doc:
	make -C docs/

test:
	julia --project=. -e 'using Pkg; Pkg.test()'

clean:
	rm -rf docs/build/

preview:
	julia -e 'using LiveServer; serve(dir="docs/build")'


.PHONY: build doc test clean preview
