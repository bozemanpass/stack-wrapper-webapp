#!/bin/bash
# Install dependencies and build a node.js service in place.
#
# Unlike the webapp wrapper, the result is not a directory of static files to be
# extracted -- the built application and its runtime dependencies stay in WORK_DIR
# and are run by start-service.sh.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ -n "$STACK_SCRIPT_DEBUG" ]; then
    set -x
fi

STACK_BUILD_TOOL="${STACK_BUILD_TOOL}"

WORK_DIR="${1:-/app}"

cd "${WORK_DIR}" || exit 1

# An app that needs something unusual can supply its own build script.
if [ -f "${WORK_DIR}/service-build.sh" ]; then
  echo "Building service with ${WORK_DIR}/service-build.sh ..."
  ./service-build.sh || exit 1
  exit 0
fi

if [ ! -f "${WORK_DIR}/package.json" ]; then
  echo "ERROR: no package.json in ${WORK_DIR} -- nothing to build." 1>&2
  echo "       A node service must be an npm package." 1>&2
  exit 1
fi

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
echo "Building package.json based service with ${STACK_BUILD_TOOL} ..."

# Install *everything* -- a TypeScript service needs its devDependencies (tsc and
# friends) to build.  They are pruned again further down.
if [ -n "${STACK_BUILD_TOOL_INSTALL_SUBCOMMAND}" ]; then
  INSTALL_CMD="${STACK_BUILD_TOOL_INSTALL_SUBCOMMAND}"
elif [ "$STACK_BUILD_TOOL" == "npm" ] && [ -f "package-lock.json" ]; then
  # 'ci' is reproducible, and errors out when the lockfile is stale rather than
  # silently resolving something else.
  INSTALL_CMD="ci"
else
  INSTALL_CMD="install"
fi

time $STACK_BUILD_TOOL $INSTALL_CMD || exit 1

# Only build if there is something to build; plain JS services have no build step.
STACK_BUILD_TOOL_BUILD_SUBCOMMAND="${STACK_BUILD_TOOL_BUILD_SUBCOMMAND}"
if [ -z "${STACK_BUILD_TOOL_BUILD_SUBCOMMAND}" ]; then
  if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
    if [ "$STACK_BUILD_TOOL" == "npm" ]; then
      STACK_BUILD_TOOL_BUILD_SUBCOMMAND="run build"
    else
      STACK_BUILD_TOOL_BUILD_SUBCOMMAND="build"
    fi
  else
    echo "No 'build' script in package.json -- skipping build step."
  fi
fi

if [ -n "${STACK_BUILD_TOOL_BUILD_SUBCOMMAND}" ]; then
  time $STACK_BUILD_TOOL $STACK_BUILD_TOOL_BUILD_SUBCOMMAND || exit 1
fi

# Drop devDependencies now that the build is done.  Set STACK_SKIP_PRUNE=true if the
# app resolves something at runtime that it declares as a devDependency.
if [ "true" != "${STACK_SKIP_PRUNE,,}" ]; then
  case "$STACK_BUILD_TOOL" in
    npm)
      echo "Pruning devDependencies ..."
      npm prune --omit=dev || exit 1
      ;;
    pnpm)
      echo "Pruning devDependencies ..."
      pnpm prune --prod || exit 1
      ;;
    *)
      echo "Not pruning devDependencies: no supported prune for ${STACK_BUILD_TOOL}."
      ;;
  esac
fi

exit 0
