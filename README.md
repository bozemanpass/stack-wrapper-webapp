# stack-wrapper-webapp

Container wrapper schemes for the [stack](https://github.com/bozemanpass/stack) tool
that build and serve node.js webapps, without the app needing to provide its own
container build:

- `webapp-base/` — generic node.js webapp (React, vite, static site generators, etc.)
- `nextjs-base/` — Next.js webapp, with runtime (rather than build-time) environment
  variable support

```
$ stack fetch repo bozemanpass/stack-wrapper-webapp
$ stack webapp build --source-repo ~/my-webapp
```

The wrapper is auto-detected from the app source (a `next` dependency in `package.json`
selects `nextjs`); select explicitly with `--wrapper webapp` or `--wrapper nextjs`.

Each wrapper directory contains a `wrapper.yml` manifest (see the stack tool's
`docs/webapp.md`), the base image `Containerfile`, the app-image `Containerfile.webapp`,
the `build.sh` build script, and the runtime scripts baked into the base image.
