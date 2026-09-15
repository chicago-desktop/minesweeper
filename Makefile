# chicago/minesweeper — lint and test on the local runtime build.

# pipefail keeps the runner's exit code while its output is streamed and the
# log is grepped afterwards.
SHELL := bash
.SHELLFLAGS := -o pipefail -ec

.PHONY: lint test

# The shell this game runs in declares the `gfx` module, and only the runtime
# fork has it (chicago-desktop/runtime, a build from its releases,
# v0.3.40a-chicago.2 or newer — the one that also resolves the shell and the
# base from their GitHub repositories by tag): `wippy` from PATH does not
# load the shell at all and says only "node with ID … not found". Point
# WIPPY at the fork's binary: `make test WIPPY=…`.
WIPPY ?= $(CURDIR)/../runtime/dist/wippy-linux-amd64
TEST_HOST := wippy.terminal:host

# Late `local`s first: a local read above its declaration is read as a global,
# that is nil, and nothing fails — `wippy lint` does not see it. Then the type
# check of this module's namespace and of the harness's tests, from the
# harness, which loads the module together with the shell it needs.
lint:
	python3 tools/late-locals.py src
	python3 tools/late-locals.py test
	cd test && $(WIPPY) lint --ns chicago.minesweeper --ns app

# The runner exits 0 when it discovers no tests; an empty discovery is always
# a defect here, so the target fails on it. The shell brings a terminal host of
# its own, so the host is named.
test:
	mkdir -p test/.wippy
	cd test && $(WIPPY) test --host $(TEST_HOST) 2>&1 | tee .wippy/last-test-run.log && ! grep -q "No tests found" .wippy/last-test-run.log
