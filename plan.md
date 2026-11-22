# durlog: project plan

## What durlog is
A crash-safe, append-only log in C. Records are appended to a single file and
identified by a 64-bit offset (the record number). Every record carries a CRC32.
On open, the log is scanned, an in-memory index is built, and any torn tail left
by a crash is truncated. This repo is my code sample for the FP Launchpad
Post-Baccalaureate Fellowship. Applications close 10 Dec 2026; I submit on 8 Dec.

## How Claude should work with me
I must write all the code and documentation myself; FP Launchpad rejects code
samples that are mainly AI-generated. So:
- Never create or edit files in src/, include/, tests/, the Makefile, DESIGN.md,
  README.md or BUGS.md. Never paste implementations of my functions in chat.
- You may create or edit only .gitignore and .github/workflows/.
- Do: explain concepts, syscalls and man pages; review my code when I ask, by
  describing the problem and giving a hint, not a rewrite; help me read compiler,
  ASan, UBSan, Valgrind and gdb output; suggest test cases in words; check my work
  against the day's "Done when"; tell me if I'm falling behind the schedule.
- When I'm stuck, give the smallest hint that unblocks me. Give a bigger one
  only if I ask.
- I work on macOS and Linux. Linux is the source of truth: a task is done only
  when `make test` passes there.

## Scope
Must have, before 8 Dec:
- My own CRC32, record encoding, append, sync, read with CRC check,
  open-time index, recovery
- Truncation, corruption and crash-simulator tests
- CLI: append, read, verify
- Clean under -Wall -Wextra, ASan and UBSan; Valgrind clean once on Linux

Out of scope until after 8 Dec: multiple segment files, an on-disk index,
benchmarks, OCaml FFI bindings, the clipboard tool.

## Design (I finalise each point in DESIGN.md)
- Record layout: | length u32 LE | crc32 u32 LE | payload |.
  The CRC covers the 4 length bytes, then the payload.
- Max payload: 1 MiB (Kafka's default ceiling is about 1 MB). Larger appends
  fail; a larger length found during recovery marks a bad record.
- Offsets: uint64_t record numbers starting at 0.
- Read memory ownership: [MY DECISION: caller-provided buffer or
  library-allocated, and why]
- Sync: explicit durlog_sync(), plus an optional sync-on-every-append flag at
  open. Guarantee: a record is durable once a sync that started after its
  append has returned. On macOS, use fcntl(fd, F_FULLFSYNC).
- Recovery: a bad or incomplete record that is the last thing in the file is a
  torn tail, so truncate and fsync. A complete bad record with more bytes after
  it means mid-file corruption, so refuse to open with a corrupt error.
- Errors: an enum with OK, out of range, too large, corrupt, I/O (keep errno),
  out of memory, invalid argument; plus a function that returns a readable
  message for each code.
- API: open, append, read, sync, close.
- One log file per directory for now.

## Layout
durlog/
  Makefile           targets: all, test, crash, clean
  CLAUDE.md  DESIGN.md  README.md  BUGS.md
  include/durlog.h
  src/               crc32.c  record.c  durlog.c  cli.c
  tests/             test_crc32.c  test_record.c  test_log.c
                     test_recovery.c  crash_sim.c
Default flags: -Wall -Wextra -g -fsanitize=address,undefined
Keep a separate build without sanitizers for Valgrind.

## Daily rhythm
- Evenings (2 h): build.
- Daytime hour: read the man page or chapter behind that evening's work.
- Mornings: OCaml basics (CS3110 chapters 2 to 5) for the tester.

## Schedule

### Sat 21 Nov: setup and design
- Repo, Makefile, empty library and test binary, DESIGN.md.
- Done when: `make` and `make test` run, and every Design point above has
  my written answer.

### Sun 22 Nov: CRC32 and little-endian helpers
- Done when: crc32("123456789") == 0xCBF43926; crc32("") == 0; computing in
  two chunks equals one call; u32 put/get round-trips.

### Mon 23 Nov: record encode/decode, in memory only
- Decode returns OK, incomplete, bad length or bad CRC.
- Done when: empty, 1-byte, 1 MiB and zero-byte-containing payloads round-trip;
  every single-bit flip is detected; a buffer cut at every possible length
  returns incomplete.

### Tue 24 Nov: open and append
- O_CREAT | O_APPEND | O_RDWR; a write-all loop that handles short writes
  and EINTR; fsync the directory when the log file is created.
- Done when: three appends produce exactly the DESIGN.md layout in `hexdump -C`.

### Wed 25 Nov: index and read
- The open-time scan builds an offset-to-position array; read uses pread,
  then checks the CRC.
- Done when: 1,000 appends, close, reopen, all read back identical; an
  out-of-range read returns the right error.

### Thu 26 Nov: recovery
- Torn tail: ftruncate, then fsync.
- Done when: the exhaustive truncation test passes. For every length L from 0
  to the file size: copy the file, cut the copy to L, open it, and check that
  the record count, the contents and the final file size are all correct.

### Fri 27 Nov: corruption and sync
- Done when: a byte flip in the last record gets truncated; a byte flip in a
  middle record makes open refuse; strace on Linux shows fsync on sync; the
  F_FULLFSYNC path builds on macOS.

### Sat 28 Nov: catch-up, then crash simulator part 1
- A child process appends deterministic records, syncs every k appends, and
  reports the last synced offset to the parent over a pipe. The parent sends
  SIGKILL at a random moment.

### Sun 29 Nov: crash simulator part 2
- The parent reopens and checks: every record up to the last synced offset is
  present, every record's content is correct, there are no gaps.
- Done when: 1,000 iterations pass. Then run 10,000 overnight.

### Mon 30 Nov: CLI
- `append <dir> <payload>` prints the offset; `read <dir> <offset>` prints the
  payload; `verify <dir>` prints the record count and status. Results go to
  stdout, errors to stderr, with meaningful exit codes.
- Done when: a full session works by hand from the shell.

### Tue 1 Dec: harden and tag v0.1
- Done when: no warnings; tests clean under ASan and UBSan on Linux and macOS;
  Valgrind clean on Linux; I can explain every syscall in an strace of an
  append followed by a sync; BUGS.md is up to date; v0.1 is tagged.

## After the core
- 2-4 Dec: an OCaml QCheck tester that runs the CLI as a separate process and
  compares every result with a list model. Keep "perform one operation" in a
  single function so it can switch to real bindings later.
- 5 Dec: README covering the design, trade-offs, how crashes are tested and
  the bugs found.
- 6-8 Dec: polish, finish the application, submit on 8 Dec.

## Staying on schedule
- An unfinished day carries over to the next evening, never by skipping its tests.
- If I'm two days behind on Fri 27 Nov, the crash simulator shrinks to part 1
  plus 1,000 iterations.
- Log every bug in BUGS.md the evening it happens.