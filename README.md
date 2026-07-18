# mdserve

> **mdserve** is a lightweight, high-performance HTTP(S) server for browsing and rendering Markdown documents. Written entirely in **ISO C11**, it is built from the ground up with **careful memory management** and **zero third-party library dependencies**, making it easy to build, audit, and deploy on **Linux** and **macOS**.
>
> When started, `mdserve` recursively scans a directory tree (with configurable depth) for Markdown files and launches a local web server. The browser presents an automatically generated index of all discovered documents. Selecting a document dynamically converts the Markdown into HTML and serves it immediately, eliminating the need to pre-generate static pages or maintain a separate documentation site.
>
> The project focuses on simplicity, portability, predictable memory usage, and minimal runtime overhead, making it suitable for local documentation browsing, project notes, knowledge bases, and embedded development environments.

`mdserve` is a small C program that lets you declare .............

---

## Requirements

- **C17** compiler (gcc or clang)
- **argp** — built into glibc on Linux; install via `brew install argp-standalone` on macOS

---

## Build

```sh
make                                # optimised release build -O3
make debug -B O_DEBUG=1             # debug build with -g3 -DDEBUG
make install                        # install to /usr/local/bin (use PREFIX= to override)
make install PREFIX="$HOME/.local"  # install to $HOME/.local
make clean
```

## Usage

```
mdserve [OPTION...] [TARGET(s)...]
```

### Options

| Flag          | Short | Place shoulder | Description                                                   |
| ------------- | ----- | -------------- | ------------------------------------------------------------- |
| `--dry-run`   | `-n`  | —              | Show what would change without making any changes             |
| `--log-level` | `-L`  | `LEVEL`        | Set log verbosity: `error`, `warn`, `info` (default), `debug` |
| `--log-file`  | `-F`  | `FILE`         | Set logging file                                              |

### Examples

```sh
# See what would be synced without making changes
mdserve --dry-run

# Verbose debug output
mdserve --log-level debug
```

---

## Project structure

```
./mdserve
└── src/
│   ├── main.c            # CLI argument parsing, sync loop
│   ├── log.h             # LOG_ERROR / LOG_WARN / LOG_INFO / LOG_DEBUG macros
│   ├── log.c             # log_record() implementation
│   └── project_config.h  # Version, name, global rclone options
└── Makefile
```

---

## License

See [LICENSE](LICENSE).
