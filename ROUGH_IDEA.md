# Rough Idea

> Running brain-dump / design scratchpad.
> Nothing here is final. Update freely as the project evolves.

---

## What is mdserve?

A fast, local-first Markdown note browser.
No Electron. No cloud. No node_modules weighing 300 MB.
Just a small C++ binary that:

1. Indexes your Markdown files.
2. Renders them to HTML on-demand via Pandoc.
3. Serves the result to your browser over a local HTTP server (Crow).

---

## Current State (v1.1.0)

- [x] Config loading (XDG + `ect/config.json` fallback, CLI overrides)
- [x] Argument parser with per-section subcommands
- [x] Logger with color, timestamps, source-location support
- [x] Recursive directory indexer → `Snapshot` (depth, extension, ignore, hidden filter)
- [x] Pandoc IPC via `pandoc.h` → `/tmp/mdserve/<session>/` output
- [x] Crow HTTP server wired up
- [x] `GET /` → full JSON config
- [x] `GET /rpc` → file index as JSON array
- [x] `POST /rpc/refresh` → re-index live
- [x] `GET /render?path=` → run pandoc, return HTML

---

## Planned Routes

```
GET  /                        full runtime config (JSON)
GET  /rpc                     list all indexed files (FileInfo[])
POST /rpc/refresh             re-walk filesystem, rebuild snapshot
GET  /render?path=<rel>       render one .md → HTML via pandoc
GET  /raw?path=<rel>          serve the raw .md source
```

---

## Data Flow

```
CLI args
    │
    ▼
load_config()          ← XDG / ect/config.json / --config flag
    │
    ▼
apply_subcommands()    ← override any key via subcommand flags
    │
    ▼
run_server(config)
    ├── build_snapshot()          walks root_directory
    │       └── FileInfo map      path, size, mtime, perms
    │
    └── Crow routes
            ├── /rpc              serialise snapshot → JSON
            ├── /render           subprocess.h → pandoc → HTML
```

---

## Pandoc / IPC Design

Each render request gets its own session directory:

```
/tmp/mdserve/
└── <timestamp>_<counter>/
    ├── note.html
    └── another-note.html
```

- Session ID = `<unix_ms>_<monotonic_counter>` (see `pandoc.cpp`).
- Rendered files are **not cleaned up automatically** yet.
  Plan: sweep `/tmp/mdserve/` on startup, or add a `TTL` config key.
- Pandoc flags in use: `--standalone` (full HTML doc with `<head>`).
  Future: `--css`, `--template`, `--lua-filter` for custom themes.
- Pandoc binary is resolved from config `pandoc.binary_path`, else `PATH`.

---

## FileInfo / Snapshot

```c
// Database metadata structure
typedef struct {
	mode_t          mode;
	char            absolute_path[PATH_MAX];
	char            file_name[256];
	size_t          file_size;  // bytes on disk

	// Optional: filesystem extras
	time_t          cTime;       // inode change time (metadata changes)
	time_t          bTime;       // birth/creation time (where supported)
	char            user[256];   // file owner name
	char            group[256];  // file group name
	struct timespec mTime;       // modification time
} FileInfo;

vfs_hash snapshots[absolute_path, FileInfo];
```

The snapshot lives in memory for the lifetime of the server.
`POST /rpc/refresh` rebuilds it without restarting.

Future ideas:

- Persist snapshot to `cache/search_index` on disk.
- Store parsed front-matter (title, tags, date) inside `FileInfo`.
- Diff old vs new snapshot to detect renames / deletes for watcher.

---

## File Watcher (todo)

Config key: `watch.enabled`.

Plan:

- Linux: inotify via a small wrapper, or `inotify`.
- macOS: FSEvents or `kqueue`.
- Fallback: polling loop (`watch.polling = true`, `watch.debounce_ms`).

On change event → call `build_snapshot()` → optionally push
an SSE (Server-Sent Event) to any open browser tabs so they
auto-reload without a manual refresh.
