# OVS Editor

OVS Editor is intended to be a stripped-down Code - OSS based text editor:

- text-file editing only
- Explorer
- Search
- Source Control / Git
- no AI features
- no marketplace/product features beyond what is needed for local text editing

The goal is to keep the familiar VS Code editing experience while reducing the
surface area to a focused editor for repositories and plain text projects.

## Proposed Base

Use Microsoft's open-source `microsoft/vscode` repository as the upstream base.
That gives us the editor, workbench, Explorer, Search, Source Control, Git
integration, settings, keybindings, theming, and the mature Electron desktop
shell.

This project should remain a fork-style downstream project with an `upstream`
remote pointing to `microsoft/vscode`, so security and editor fixes can still be
merged deliberately.

## Initial Scope

Keep:

- workbench shell
- Monaco text editor
- Explorer view
- Search view
- Source Control view
- built-in Git support
- settings and keybindings required by those features
- local file/folder/workspace support

Remove or disable:

- AI/chat/inline chat features
- extension marketplace entry points
- remote development entry points
- notebooks
- debug UI
- terminal UI, unless needed later
- accounts, sync, telemetry, walkthroughs, welcome flows, and promotional UI
- language-specific bundled features that are not required for plain text

## Import Plan

1. Add `microsoft/vscode` as `upstream`.
2. Import the upstream source into this repository.
3. Build unmodified Code - OSS once, to prove the toolchain works.
4. Rebrand the product metadata to OVS Editor.
5. Disable unwanted workbench contributions at product/configuration level where
   possible.
6. Remove dead commands, menus, views, and bundled extensions in small commits.
7. Add smoke tests for:
   - opening a folder
   - editing and saving a text file
   - searching files
   - viewing Git changes
   - committing through Source Control

## Detailed First Steps

These steps assume this repository starts as the downstream project and
`microsoft/vscode` is the upstream project that we periodically merge from.

### 1. Add Microsoft VS Code as `upstream`

Check the current remotes:

```bash
git remote -v
```

`origin` should be this project, for example:

```text
origin  git@github.com:zebasxx/OVSEditor.git (fetch)
origin  git@github.com:zebasxx/OVSEditor.git (push)
```

Add Code - OSS as a second remote:

```bash
git remote add upstream https://github.com/microsoft/vscode.git
```

Verify it:

```bash
git remote -v
```

You should now see both `origin` and `upstream`.

### 2. Import the upstream source

Because this project is meant to become a fork-style downstream of Code - OSS,
the cleanest first import is to base `main` on upstream `main`.

First fetch upstream:

```bash
git fetch upstream main
```

Then create a local import branch from upstream:

```bash
git switch -c import-code-oss upstream/main
```

At this point the working tree should contain the full VS Code source.

Then push that branch to this project's GitHub repo:

```bash
git push -u origin import-code-oss
```

After that, we can either:

- open a pull request from `import-code-oss` into `main`, or
- make `import-code-oss` the new `main` after confirming the import is good.

The pull request route is safer because the source import is very large.

### 3. Build unmodified Code - OSS in Docker

Do this before changing branding or removing features. It proves the base source
is healthy while keeping the Node runtime and native build dependencies out of
the host machine.

Preferred host requirements:

- Docker
- VS Code with the Dev Containers extension, or the standalone Dev Container CLI

The Code - OSS repository already includes a `.devcontainer` setup, so after the
upstream source has been imported we should use that instead of installing the
toolchain directly on the host.

#### Option A: VS Code Dev Containers

Open the imported Code - OSS branch in VS Code and run:

```text
Dev Containers: Reopen in Container
```

That builds and opens the repository inside the Docker container described by the
upstream `.devcontainer` files.

Then, from a terminal inside the container:

```bash
npm install
npm run watch
```

Wait until the terminal says the initial compilation finished. Keep this process
running.

This proves the source compiles without installing Node or native build packages
on the host.

#### Option B: Dev Container CLI

If we want to do it without clicking through VS Code, install the Dev Container
CLI once and let it drive Docker:

```bash
npm install -g @devcontainers/cli
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . npm install
devcontainer exec --workspace-folder . npm run watch
```

That still installs the project dependencies inside the container, not on the
host.

#### Running the app

The pure compile check should happen inside Docker first. Running the Electron
desktop UI from Docker is possible, but it requires extra display forwarding
setup for X11 or Wayland.

For the first milestone we should treat this as enough:

- container builds successfully
- `npm run watch` completes initial compilation
- no host Node/npm dependency setup is needed

After that, we can choose one of two run strategies:

- run a web/server variant from the container for quick UI checks
- add Linux display forwarding to run the Electron desktop app from Docker

If we later decide to run the desktop app directly on the host, the command is:

```bash
./scripts/code.sh
```

But that should be optional, not the default setup path.

### 4. Rebrand the product metadata

Only rebrand after the unmodified build works.

The first files to inspect are usually:

```text
product.json
resources/linux/code.desktop
resources/linux/code-url-handler.desktop
resources/server/code-web.sh
```

The likely product metadata changes are:

- application name: `OVS Editor`
- data folder name: something like `.ovs-editor-oss`
- command name: something like `ovs-editor`
- URL protocol: something like `ovs-editor`
- icons and desktop launcher names

We should make this as a separate commit from the source import, so if anything
breaks we know whether the problem came from upstream or our branding change.

## Notes

This should be treated as a reduction project, not a rewrite. The safest path is
to first keep upstream building, then remove features in layers while preserving
the editor core.
