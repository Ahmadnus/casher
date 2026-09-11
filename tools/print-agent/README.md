# Casher Print Agent

A ~90 KB Windows program that lets the **Casher web POS** (running in a
browser) print to the thermal/POS printers attached to the cashier's PC.

```
Flutter Web (browser)  ──HTTP 127.0.0.1:9123──▶  CasherPrintAgent.exe  ──RAW──▶  Receipt / Kitchen printer
```

The browser sends the **same ESC/POS bytes** the desktop app builds; the agent
writes them to the Windows print spooler in RAW mode, which is exactly how the
desktop plugin prints. Any printer Windows knows about works (USB, serial,
network, shared) and the cashier never sees a print dialog.

## Requirements on the customer's PC

* Windows 7 SP1, 8, 8.1, 10 or 11 (32 or 64 bit).
* .NET Framework 4.0 or newer — built into Windows 8+, and already present on
  practically every Windows 7 machine that has had Windows Update run.
* The printer installed in Windows with its own driver or **Generic / Text Only**.

No admin rights are needed: the agent listens on loopback only (TcpListener,
not HttpListener, so no `netsh urlacl` step) and prints as the logged-in user.

## Install (one time per cashier PC)

1. Copy `CasherPrintAgent.exe` anywhere (e.g. `C:\Casher\`).
2. Double-click it. A printer icon appears in the tray: **Casher Print Agent**.
3. Right-click the tray icon → tick **Start with Windows**.
4. In the web POS open **إعدادات الطابعات**. The card at the top should say the
   agent is connected; the list below shows every Windows printer. Assign one
   as **طابعة الفاتورة** and one as **طابعة الكاش** and press **تجربة طباعة**.

Multiple printers: every job is addressed by printer name, so the receipt and
kitchen printers can be any two (or the same) queues. Adding more roles later
only needs a new slot in `PrinterService` — the agent needs no change.

## Command line

```
CasherPrintAgent.exe [--port 9123] [--token SECRET] [--no-tray]
```

* `--port`   listen port (default 9123). Change it in the POS settings too.
* `--token`  optional shared secret; the POS must then send `X-Agent-Token`.
* `--no-tray` headless (e.g. as a scheduled task / service wrapper).

Log file: `%LOCALAPPDATA%\CasherPrintAgent\agent.log`.
Status page: open `http://127.0.0.1:9123/` in a browser.

## HTTP API

| Method | Path        | Body / Result |
|--------|-------------|---------------|
| GET    | `/health`   | `{ok, name, version, port, requires_token}` |
| GET    | `/printers` | `{ok, printers:[{name, is_default}]}` |
| POST   | `/print`    | `{printer, data (base64 ESC/POS), job_name?}` → `{ok, bytes}` |
| POST   | `/test`     | `{printer}` → prints a test ticket |
| OPTIONS| `*`         | CORS preflight, incl. `Access-Control-Allow-Private-Network` |

CORS allows any origin; only code running in the user's own browser can reach
`127.0.0.1`. Browsers treat loopback as a secure context, so the HTTPS-hosted
POS may call the plain-HTTP agent (Chrome additionally requires the
Private-Network preflight header, which the agent returns).

## Build

Needs nothing but Windows — the C# compiler ships with .NET Framework:

```
build.bat
```

produces `CasherPrintAgent.exe` next to the source.
