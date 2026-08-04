# stack-wrapper-webapp

Container wrapper schemes for the [stack](https://github.com/bozemanpass/stack) tool
that build and run node.js applications, without the app needing to provide its own
container build:

- `webapp-base/` — generic node.js webapp (React, vite, static site generators, etc.)
- `nextjs-base/` — Next.js webapp, with runtime (rather than build-time) environment
  variable support
- `node-service-base/` — long-running node.js service (Express, Fastify, etc.)

```
$ stack fetch repo bozemanpass/stack-wrapper-webapp
$ stack webapp build --source-repo ~/my-webapp
```

The wrapper is auto-detected from the app source (a `next` dependency in `package.json`
selects `nextjs`, an `express` dependency selects `node-service`); select explicitly with
`--wrapper webapp`, `--wrapper nextjs` or `--wrapper node-service`.

Each wrapper directory contains a `wrapper.yml` manifest (see the stack tool's
`docs/wrappers.md`), the base image `Containerfile`, the app-image containerfile named by
the manifest, the `build.sh` build script, and the runtime scripts baked into the base
image.

## Webapps vs services

The first two wrappers produce *static content*: the app is built, its output directory
(`dist`, `build`, `.next`) becomes the image payload, and a web server in the base image
serves it. Because the result runs in a browser, which has no environment of its own,
build-time placeholders are rewritten at container start so one image can be deployed to
many environments.

`node-service` is different in kind. The application process *is* the server, so the
build keeps `package.json` and the installed `node_modules` alongside any compiled
output, and the container start command runs the app. Nothing is substituted at startup:
a node process reads `process.env` directly, so ordinary container environment variables
already do the job.

### node-service specifics

The build runs the package manager's install (`npm ci` when a `package-lock.json` is
present), then `npm run build` **only if** `package.json` declares a `build` script — a
plain JavaScript service with no compile step needs no configuration. `devDependencies`
are pruned afterwards, so a TypeScript service gets `tsc` at build time but ships without
it.

At start, the wrapper runs `npm start` if the package declares one, otherwise `node`
against the package's `main` entry point.

`PORT` is set to the wrapper's port (3000), which most node servers already honor.
Applications reading something else can be pointed at it explicitly.

| Variable | Effect |
|----------|--------|
| `STACK_START_COMMAND` | Run this instead of `npm start` / `main` |
| `STACK_LISTEN_PORT` | Port to serve on; exported as `PORT` (default 3000) |
| `STACK_BUILD_TOOL` | Force `npm` / `yarn` / `pnpm` / `bun` instead of detecting from the lockfile |
| `STACK_BUILD_TOOL_INSTALL_SUBCOMMAND` | Override the install command |
| `STACK_BUILD_TOOL_BUILD_SUBCOMMAND` | Override the build command |
| `STACK_SKIP_PRUNE` | Set `true` to keep `devDependencies` in the final image |
| `STACK_SERVICE_DIR` | Where the app lives in the image (default `/app`) |

A service needing something the above cannot express can provide its own
`service-build.sh` in the source root, which the wrapper runs in place of the whole
install/build/prune sequence.
