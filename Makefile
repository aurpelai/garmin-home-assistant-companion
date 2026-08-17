# Convenience wrapper around the Connect IQ toolchain.
#
# Requires the Connect IQ SDK on PATH, or set CIQ_SDK to the SDK root, e.g.:
#   export CIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<version>"
# A developer key is needed to sign builds:
#   make key            # generate developer_key.der (once)

DEVICE ?= fenix8solar51mm
KEY    ?= developer_key.der
JUNGLE ?= monkey.jungle

# The unit-test build layers test.jungle on top to swap in mock settings; app
# builds use the production jungle alone.
TEST_JUNGLE ?= $(JUNGLE);test.jungle

# Type-check level. 3 = strictest (errors on type mismatches). This is the
# project standard — CI also compiles at -l 3.
TYPECHECK ?= 3

# Strict flags applied to every compile: -l 3 (type checking) + -w (show
# compiler warnings, e.g. unused variables / unreachable code). monkeyc has no
# warnings-as-errors flag, so `make lint` greps for WARNING and fails on any.
STRICT := -l $(TYPECHECK) -w

# Resolve tool paths: prefer $CIQ_SDK/bin, else assume on PATH.
ifdef CIQ_SDK
  MONKEYC := $(CIQ_SDK)/bin/monkeyc
  MONKEYDO := $(CIQ_SDK)/bin/monkeydo
  CONNECTIQ := $(CIQ_SDK)/bin/connectiq
else
  MONKEYC := monkeyc
  MONKEYDO := monkeydo
  CONNECTIQ := connectiq
endif

.PHONY: build test lint sim run key clean

build: ## Compile a debug build for $(DEVICE)
	@mkdir -p bin
	"$(MONKEYC)" -f $(JUNGLE) -d $(DEVICE) -o bin/app.prg -y $(KEY) $(STRICT)

# Fail on any compiler warning: capture output, print it, exit non-zero if a
# WARNING line is present (monkeyc has no -Werror).
lint: ## Compile with -l 3 -w and fail on any warning
	@mkdir -p bin
	@out=$$("$(MONKEYC)" -f $(JUNGLE) -d $(DEVICE) -o bin/lint.prg -y $(KEY) $(STRICT) 2>&1); \
	echo "$$out"; \
	if echo "$$out" | grep -qE '^WARNING'; then echo "FAIL: compiler warnings present"; exit 1; fi

test: ## Build + run unit tests in the simulator (must be running: make sim)
	@mkdir -p bin
	"$(MONKEYC)" -f "$(TEST_JUNGLE)" -d $(DEVICE) --unit-test -o bin/test.prg -y $(KEY) $(STRICT)
	"$(MONKEYDO)" bin/test.prg $(DEVICE) -t

sim: ## Launch the Connect IQ simulator (opens it, then returns)
	"$(CONNECTIQ)"

run: build ## Launch the (strict-built) app in the simulator (must be running)
	"$(MONKEYDO)" bin/app.prg $(DEVICE)

key: ## Generate a developer signing key (once)
	openssl genrsa -out /tmp/ciq_key.pem 4096
	openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/ciq_key.pem -out $(KEY) -nocrypt
	@rm -f /tmp/ciq_key.pem
	@echo "Wrote $(KEY) (git-ignored)."

clean: ## Remove build output
	rm -rf bin
