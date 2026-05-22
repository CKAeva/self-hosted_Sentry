# Log Rotation — `application`

This section documents the automated log rotation setup for `application`, managed by the orchestrator script at `/var/log/log_rotate.sh`.

---

## How the Script Works

`log_rotate.sh` is a hardened wrapper around the standard `logrotate` utility. It adds structured observability, safe concurrency control, and explicit failure handling on top of what `logrotate` does natively.

**Execution pipeline, in order:**

1. **Structured logging initialised** — Every event the script emits is written as a JSON object (`timestamp`, `level`, `message`) to both stdout and the central log at `/var/log/log_orchestrator.log`. This makes log output machine-parseable and easy to forward to log aggregators.

2. **Root check** — The script immediately exits with a `FATAL` log entry if it is not running as `root`. `logrotate` requires root to read protected log files and write rotated archives.

3. **Lock acquisition** — A file lock is placed on `/var/log/log_orchestrator.lock` using `flock -n` (non-blocking, exclusive). If another instance of the script is already running, the new invocation logs a `WARN` and exits cleanly rather than racing. The lock is released automatically when the script exits.

4. **Config validation** — The script confirms that the `logrotate` config at `/etc/logrotate.d/application` actually exists before proceeding. A missing config exits with `FATAL`.

5. **Output directory creation** — `/var/log/apps/` is created with `mkdir -p` if it does not already exist, preventing `logrotate` from failing on wildcard path expansion.

6. **`logrotate` execution** — `logrotate` runs with a dedicated state file (`/var/log/hourly.state`) so its rotation bookkeeping is isolated from the system-wide state. `stdout` and `stderr` are captured together. On success, an `INFO` entry is logged. On failure, the raw output is sanitised (double-quotes replaced with single-quotes to preserve JSON validity) and logged as `ERROR`, and the script exits non-zero.

7. **Error trap** — A `trap` on `ERR` catches any unexpected command failure anywhere in the script, logs the offending line number and exit code, and exits. No failure is silently swallowed.

---

## Log Retention and Archival Logic

Retention behaviour is controlled by `/etc/logrotate.d/application` (shown below as a reference; `application` should mirror this policy unless configured differently).

```
/var/log/application.log {
    daily           # Rotate once per day
    rotate 5        # Keep 5 rotated files; the 6th causes the oldest to be deleted
    compress        # Compress rotated files with gzip (.gz)
    delaycompress   # Skip compressing the most recently rotated file (keeps it readable for live log shippers)
    missingok       # Do not error if the log file is absent
    notifempty      # Skip rotation if the log file is empty
    copytruncate    # Copy the active log, then truncate in place — no restart of the writing process required
    create 0640 root root  # Recreate the log file after rotation with these permissions and ownership
}
```

**What this means in practice:**

| Concern | Behaviour |
|---|---|
| Retention window | 5 days of rotated logs are kept on disk at all times |
| Disk footprint | Rotated files are gzip-compressed, typically reducing size by 70–90% |
| Live writer safety | `copytruncate` means `application` never needs to be signalled or restarted during rotation |
| Hot file | The most-recently rotated file is left uncompressed for one cycle (`delaycompress`), so a log shipper or `tail` command can still read it without decompressing |
| Missing / empty logs | Both are handled gracefully — no alerts are triggered when the log file is absent or zero bytes |
| State isolation | The `-s /var/log/hourly.state` flag passed at runtime keeps this job's rotation state separate from `/var/lib/logrotate/status`, so it does not interfere with other system-managed logs |

---

## Cron Schedule

The script is scheduled via the following crontab entry:

```cron
0 0 * * * /var/log/log_rotate.sh
```

| Field | Value | Meaning |
|---|---|---|
| Minute | `0` | At minute zero |
| Hour | `0` | At midnight (00:00) |
| Day of month | `*` | Every day |
| Month | `*` | Every month |
| Day of week | `*` | Every day of the week |

**Net effect:** The script runs once per day at midnight (server local time). Combined with the `rotate 5` directive, this gives a rolling **5-day retention window**.

> **Note:** The cron entry runs as `root` (add to root's crontab with `sudo crontab -e`). Running it as any other user will cause the permission check to abort the script immediately.

---

## Testing the Script Manually

### Dry-run (no files changed)

Use `logrotate`'s built-in `--debug` flag to simulate a full rotation cycle without touching any files:

```bash
sudo /sbin/logrotate --debug -s /var/log/hourly.state /etc/logrotate.d/application
```

This prints exactly what `logrotate` *would* do — which files would be rotated, compressed, or deleted — without actually doing it.

### Force a real rotation

If you need to trigger an actual rotation immediately (useful after a config change or to verify the full pipeline end-to-end):

```bash
sudo /sbin/logrotate --force -s /var/log/hourly.state /etc/logrotate.d/application
```

`--force` bypasses the "already rotated today" check in the state file.

### Run the full orchestrator script

To exercise the script exactly as cron does — including locking, JSON logging, and error handling:

```bash
sudo /var/log/log_rotate.sh
```

Then inspect the structured output log:

```bash
cat /var/log/log_orchestrator.log | python3 -m json.tool
# or, if jq is available:
cat /var/log/log_orchestrator.log | jq .
```

### Verify rotation state

Check what `logrotate` has recorded in its state file to confirm the last rotation timestamp:

```bash
grep application /var/log/hourly.state
```

### Confirm lock behaviour

To verify the concurrency guard works, start a long-running dummy process holding the lock, then invoke the script in a second terminal:

```bash
# Terminal 1 — hold the lock
flock /var/log/log_orchestrator.lock sleep 30

# Terminal 2 — should log WARN and exit 0 immediately
sudo /var/log/log_rotate.sh
```

Expected output in Terminal 2:
```json
{"timestamp":"...","level":"WARN","message":"Another instance of this script is currently running. Exiting to prevent concurrent execution."}
```
