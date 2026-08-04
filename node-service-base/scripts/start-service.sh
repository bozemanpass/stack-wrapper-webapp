#!/usr/bin/env bash
# Run the wrapped node.js service.
#
# No runtime environment substitution happens here: unlike a browser bundle, a node
# service reads process.env directly at startup, so ordinary container environment
# variables just work.
if [ -n "$STACK_SCRIPT_DEBUG" ]; then
    set -x
fi

STACK_SERVICE_DIR="${STACK_SERVICE_DIR:-/app}"
STACK_LISTEN_PORT="${STACK_LISTEN_PORT:-${PORT:-3000}}"

# Export both spellings: PORT is the node convention, STACK_LISTEN_PORT is the stack one.
export PORT="${STACK_LISTEN_PORT}"
export STACK_LISTEN_PORT

cd "${STACK_SERVICE_DIR}" || exit 1

if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

STACK_BUILD_TOOL="${STACK_BUILD_TOOL}"
if [ -z "$STACK_BUILD_TOOL" ]; then
  if [ -f "pnpm-lock.yaml" ]; then
    STACK_BUILD_TOOL=pnpm
  elif [ -f "yarn.lock" ]; then
    STACK_BUILD_TOOL=yarn
  elif [ -f "bun.lockb" ]; then
    STACK_BUILD_TOOL=bun
  else
    STACK_BUILD_TOOL=npm
  fi
fi

# An explicit command wins; otherwise prefer the package's own start script, and
# fall back to its declared entry point.
if [ -n "${STACK_START_COMMAND}" ]; then
  echo "Starting service on port ${PORT}: ${STACK_START_COMMAND}"
  # Via bash -c so that quoting in the command string is honored rather than being
  # flattened by word splitting.  bash execs a simple command in place, so the
  # service still receives signals directly.
  exec bash -c "${STACK_START_COMMAND}"
elif jq -e '.scripts.start' package.json >/dev/null 2>&1; then
  echo "Starting service on port ${PORT}: ${STACK_BUILD_TOOL} start"
  exec $STACK_BUILD_TOOL start
else
  MAIN=$(jq -r '.main // empty' package.json 2>/dev/null)
  if [ -n "${MAIN}" ] && [ -f "${MAIN}" ]; then
    echo "Starting service on port ${PORT}: node ${MAIN}"
    exec node "${MAIN}"
  fi
  echo "ERROR: don't know how to start this service." 1>&2
  echo "       Add a 'start' script to package.json, or set STACK_START_COMMAND." 1>&2
  exit 1
fi
