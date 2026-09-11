// Casher Print Agent
// ------------------
// Tiny local HTTP bridge between the Casher POS web app (running in a browser)
// and the thermal/POS printers installed on this Windows machine.
//
//   Flutter Web  --HTTP (127.0.0.1:9123)-->  CasherPrintAgent  --RAW spooler-->  Printer
//
// The browser sends the SAME ESC/POS byte stream the desktop app builds; the
// agent writes it to the Windows print queue in RAW mode (winspool.drv), which
// is exactly how the desktop plugin prints. Any printer the spooler knows
// (USB, serial, network, shared) works, and the cashier never sees a dialog.
//
// Built with the C# compiler that ships inside .NET Framework 4.x, so it runs
// on Windows 7 SP1 / 8 / 8.1 / 10 / 11 with no extra runtime (build.bat).
//
// Endpoints (JSON, CORS enabled for any origin, loopback only):
//   GET  /health            -> {ok, name, version, port}
//   GET  /printers          -> {printers:[{name,is_default}]}
//   POST /print             -> body {printer, data(base64 ESC/POS), job_name?}
//   POST /test              -> body {printer}
//   OPTIONS *               -> CORS preflight (incl. Private Network Access)
//
// Optional shared secret: start with  CasherPrintAgent.exe --token SECRET
// and the web app must send header  X-Agent-Token: SECRET.

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Printing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace CasherPrintAgent
{
    internal static class Program
    {
        public const string Version = "1.0.0";
        public const string AppName = "Casher Print Agent";

        [STAThread]
        private static void Main(string[] args)
        {
            int port = 9123;
            string token = null;
            bool noTray = false;

            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i].ToLowerInvariant();
                if (a == "--port" && i + 1 < args.Length) { int.TryParse(args[++i], out port); }
                else if (a == "--token" && i + 1 < args.Length) { token = args[++i]; }
                else if (a == "--no-tray") { noTray = true; }
            }

            // Single instance per port.
            bool created;
            var mutex = new Mutex(true, "Global\\CasherPrintAgent_" + port, out created);
            if (!created)
            {
                MessageBox.Show("Casher Print Agent is already running on port " + port + ".",
                    AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            Log.Info("Starting " + AppName + " v" + Version + " on 127.0.0.1:" + port);

            var server = new HttpServer(port, token);
            try
            {
                server.Start();
            }
            catch (Exception ex)
            {
                Log.Error("Cannot listen on port " + port + ": " + ex.Message);
                MessageBox.Show("Cannot listen on port " + port + ":\n" + ex.Message, AppName,
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            if (noTray)
            {
                // Headless mode (e.g. run as a scheduled task): block forever.
                Thread.Sleep(Timeout.Infinite);
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (var tray = new TrayContext(server, port))
            {
                Application.Run(tray);
            }
            server.Stop();
            GC.KeepAlive(mutex);
        }
    }

    // ───────────────────────────── Tray icon ─────────────────────────────

    internal sealed class TrayContext : ApplicationContext
    {
        private readonly NotifyIcon _icon;
        private readonly HttpServer _server;
        private readonly int _port;
        private readonly MenuItem _autostart;

        public TrayContext(HttpServer server, int port)
        {
            _server = server;
            _port = port;

            var menu = new ContextMenu();
            menu.MenuItems.Add(new MenuItem(Program.AppName + " v" + Program.Version) { Enabled = false });
            menu.MenuItems.Add(new MenuItem("Listening on 127.0.0.1:" + port) { Enabled = false });
            menu.MenuItems.Add("-");
            menu.MenuItems.Add(new MenuItem("Open status page", (s, e) => OpenStatus()));
            menu.MenuItems.Add(new MenuItem("Show printers", (s, e) => ShowPrinters()));
            menu.MenuItems.Add(new MenuItem("Open log folder", (s, e) => OpenLog()));
            menu.MenuItems.Add("-");
            _autostart = new MenuItem("Start with Windows", (s, e) => ToggleAutostart());
            _autostart.Checked = Autostart.IsEnabled();
            menu.MenuItems.Add(_autostart);
            menu.MenuItems.Add("-");
            menu.MenuItems.Add(new MenuItem("Exit", (s, e) => ExitThread()));

            _icon = new NotifyIcon
            {
                Icon = SystemIcons.Application,
                Text = Program.AppName + " (port " + port + ")",
                ContextMenu = menu,
                Visible = true,
            };
            _icon.DoubleClick += (s, e) => OpenStatus();
            _icon.ShowBalloonTip(3000, Program.AppName, "Running. Web POS can now print to local printers.", ToolTipIcon.Info);
        }

        private void OpenStatus()
        {
            try { System.Diagnostics.Process.Start("http://127.0.0.1:" + _port + "/"); } catch { }
        }

        private void OpenLog()
        {
            try { System.Diagnostics.Process.Start("explorer.exe", Log.Folder); } catch { }
        }

        private void ShowPrinters()
        {
            var sb = new StringBuilder();
            foreach (var p in Printers.List())
            {
                sb.Append(p.IsDefault ? "* " : "  ").AppendLine(p.Name);
            }
            MessageBox.Show(sb.Length == 0 ? "No printers installed." : sb.ToString(), "Installed printers",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void ToggleAutostart()
        {
            bool enable = !_autostart.Checked;
            Autostart.Set(enable, _port);
            _autostart.Checked = enable;
        }

        protected override void ExitThreadCore()
        {
            _icon.Visible = false;
            _icon.Dispose();
            _server.Stop();
            base.ExitThreadCore();
        }
    }

    internal static class Autostart
    {
        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string ValueName = "CasherPrintAgent";

        public static bool IsEnabled()
        {
            try
            {
                using (var k = Registry.CurrentUser.OpenSubKey(RunKey, false))
                {
                    return k != null && k.GetValue(ValueName) != null;
                }
            }
            catch { return false; }
        }

        public static void Set(bool enable, int port)
        {
            try
            {
                using (var k = Registry.CurrentUser.OpenSubKey(RunKey, true))
                {
                    if (k == null) return;
                    if (enable)
                    {
                        k.SetValue(ValueName, "\"" + Application.ExecutablePath + "\" --port " + port);
                    }
                    else
                    {
                        k.DeleteValue(ValueName, false);
                    }
                }
            }
            catch (Exception ex) { Log.Error("Autostart: " + ex.Message); }
        }
    }

    // ───────────────────────────── Logging ─────────────────────────────

    internal static class Log
    {
        private static readonly object Gate = new object();

        public static string Folder
        {
            get
            {
                string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CasherPrintAgent");
                try { Directory.CreateDirectory(dir); } catch { }
                return dir;
            }
        }

        public static void Info(string msg) { Write("INFO ", msg); }
        public static void Error(string msg) { Write("ERROR", msg); }

        private static void Write(string level, string msg)
        {
            try
            {
                lock (Gate)
                {
                    string file = Path.Combine(Folder, "agent.log");
                    var fi = new FileInfo(file);
                    if (fi.Exists && fi.Length > 2 * 1024 * 1024) fi.Delete(); // keep it small
                    File.AppendAllText(file, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + level + " " + msg + Environment.NewLine);
                }
            }
            catch { }
        }
    }

    // ───────────────────────────── Printers ─────────────────────────────

    internal sealed class PrinterInfo
    {
        public string Name;
        public bool IsDefault;
    }

    internal static class Printers
    {
        public static List<PrinterInfo> List()
        {
            var result = new List<PrinterInfo>();
            string def = null;
            try { def = new PrinterSettings().PrinterName; } catch { }

            try
            {
                foreach (string name in PrinterSettings.InstalledPrinters)
                {
                    result.Add(new PrinterInfo { Name = name, IsDefault = string.Equals(name, def, StringComparison.OrdinalIgnoreCase) });
                }
            }
            catch (Exception ex) { Log.Error("Enumerating printers: " + ex.Message); }

            return result;
        }

        public static bool Exists(string name)
        {
            foreach (var p in List())
            {
                if (string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }
    }

    /// <summary>
    /// Sends raw bytes straight to a spooler queue (the classic RawPrinterHelper).
    /// The printer driver must be a "Generic / Text Only" or the vendor's
    /// ESC/POS driver — which is what every thermal printer installs.
    /// </summary>
    internal static class RawPrinter
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private class DOCINFOW
        {
            [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
            [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
            [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
        }

        [DllImport("winspool.drv", EntryPoint = "OpenPrinterW", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPWStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

        [DllImport("winspool.drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool ClosePrinter(IntPtr hPrinter);

        [DllImport("winspool.drv", EntryPoint = "StartDocPrinterW", SetLastError = true, CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOW di);

        [DllImport("winspool.drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool EndDocPrinter(IntPtr hPrinter);

        [DllImport("winspool.drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool StartPagePrinter(IntPtr hPrinter);

        [DllImport("winspool.drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool EndPagePrinter(IntPtr hPrinter);

        [DllImport("winspool.drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

        public static void Send(string printerName, byte[] bytes, string jobName)
        {
            IntPtr hPrinter;
            if (!OpenPrinter(printerName, out hPrinter, IntPtr.Zero))
            {
                throw new Exception("OpenPrinter failed (" + Marshal.GetLastWin32Error() + ") for '" + printerName + "'");
            }

            try
            {
                var di = new DOCINFOW { pDocName = string.IsNullOrEmpty(jobName) ? "Casher POS" : jobName, pDataType = "RAW" };
                if (!StartDocPrinter(hPrinter, 1, di))
                    throw new Exception("StartDocPrinter failed (" + Marshal.GetLastWin32Error() + ")");
                try
                {
                    if (!StartPagePrinter(hPrinter))
                        throw new Exception("StartPagePrinter failed (" + Marshal.GetLastWin32Error() + ")");
                    try
                    {
                        IntPtr unmanaged = Marshal.AllocCoTaskMem(bytes.Length);
                        try
                        {
                            Marshal.Copy(bytes, 0, unmanaged, bytes.Length);
                            int written;
                            if (!WritePrinter(hPrinter, unmanaged, bytes.Length, out written) || written != bytes.Length)
                                throw new Exception("WritePrinter failed (" + Marshal.GetLastWin32Error() + "), wrote " + written + "/" + bytes.Length);
                        }
                        finally { Marshal.FreeCoTaskMem(unmanaged); }
                    }
                    finally { EndPagePrinter(hPrinter); }
                }
                finally { EndDocPrinter(hPrinter); }
            }
            finally { ClosePrinter(hPrinter); }
        }

        public static byte[] TestTicket(string printerName)
        {
            var buf = new List<byte>();
            buf.AddRange(new byte[] { 0x1B, 0x40 });          // init
            buf.AddRange(new byte[] { 0x1B, 0x61, 0x01 });    // center
            buf.AddRange(Encoding.ASCII.GetBytes("Casher Print Agent\n"));
            buf.AddRange(Encoding.ASCII.GetBytes("Test Print OK\n"));
            buf.AddRange(Encoding.ASCII.GetBytes(printerName + "\n"));
            buf.AddRange(Encoding.ASCII.GetBytes(DateTime.Now.ToString("yyyy-MM-dd HH:mm") + "\n"));
            buf.AddRange(Encoding.ASCII.GetBytes("----------------------------\n\n\n\n"));
            buf.AddRange(new byte[] { 0x1D, 0x56, 0x41, 0x03 }); // cut
            return buf.ToArray();
        }
    }

    // ───────────────────────────── HTTP server ─────────────────────────────
    //
    // Deliberately a hand-rolled server on TcpListener instead of HttpListener:
    // HttpListener needs a URL ACL (netsh http add urlacl) or admin rights on
    // Vista+, which is exactly what we cannot ask a cashier to set up.

    internal sealed class HttpRequest
    {
        public string Method;
        public string Path;
        public Dictionary<string, string> Headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public string Body;

        public string Header(string name)
        {
            string v;
            return Headers.TryGetValue(name, out v) ? v : null;
        }
    }

    internal sealed class HttpServer
    {
        private readonly int _port;
        private readonly string _token;
        private TcpListener _listener;
        private volatile bool _running;

        public HttpServer(int port, string token)
        {
            _port = port;
            _token = token;
        }

        public void Start()
        {
            _listener = new TcpListener(IPAddress.Loopback, _port);
            _listener.Start();
            _running = true;
            var t = new Thread(AcceptLoop) { IsBackground = true, Name = "http-accept" };
            t.Start();
        }

        public void Stop()
        {
            _running = false;
            try { if (_listener != null) _listener.Stop(); } catch { }
        }

        private void AcceptLoop()
        {
            while (_running)
            {
                TcpClient client;
                try { client = _listener.AcceptTcpClient(); }
                catch { if (!_running) return; continue; }

                ThreadPool.QueueUserWorkItem(_ => Handle(client));
            }
        }

        private void Handle(TcpClient client)
        {
            try
            {
                client.ReceiveTimeout = 10000;
                client.SendTimeout = 10000;
                using (var stream = client.GetStream())
                {
                    HttpRequest req = Parse(stream);
                    if (req == null) return;

                    int status;
                    string body;
                    string contentType = "application/json; charset=utf-8";

                    try
                    {
                        body = Route(req, out status, ref contentType);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(req.Method + " " + req.Path + " -> " + ex.Message);
                        status = 500;
                        body = Json.Obj("ok", false, "error", ex.Message);
                    }

                    WriteResponse(stream, status, body, contentType, req);
                }
            }
            catch (Exception ex)
            {
                Log.Error("Connection: " + ex.Message);
            }
            finally
            {
                try { client.Close(); } catch { }
            }
        }

        private string Route(HttpRequest req, out int status, ref string contentType)
        {
            status = 200;

            if (req.Method == "OPTIONS")
            {
                status = 204;
                return "";
            }

            if (req.Path == "/" && req.Method == "GET")
            {
                contentType = "text/html; charset=utf-8";
                return StatusPage();
            }

            if (req.Path == "/health" && req.Method == "GET")
            {
                return Json.Obj("ok", true, "name", Program.AppName, "version", Program.Version, "port", _port,
                    "requires_token", !string.IsNullOrEmpty(_token));
            }

            if (!string.IsNullOrEmpty(_token) && req.Header("X-Agent-Token") != _token)
            {
                status = 401;
                return Json.Obj("ok", false, "error", "invalid agent token");
            }

            if (req.Path == "/printers" && req.Method == "GET")
            {
                var sb = new StringBuilder("{\"ok\":true,\"printers\":[");
                bool first = true;
                foreach (var p in Printers.List())
                {
                    if (!first) sb.Append(',');
                    first = false;
                    sb.Append("{\"name\":").Append(Json.Str(p.Name)).Append(",\"is_default\":").Append(p.IsDefault ? "true" : "false").Append('}');
                }
                sb.Append("]}");
                return sb.ToString();
            }

            if ((req.Path == "/print" || req.Path == "/test") && req.Method == "POST")
            {
                var fields = Json.ParseFlat(req.Body ?? "");
                string printer;
                fields.TryGetValue("printer", out printer);

                if (string.IsNullOrEmpty(printer))
                {
                    status = 422;
                    return Json.Obj("ok", false, "error", "printer is required");
                }
                if (!Printers.Exists(printer))
                {
                    status = 404;
                    return Json.Obj("ok", false, "error", "printer not installed: " + printer);
                }

                byte[] bytes;
                string jobName;
                fields.TryGetValue("job_name", out jobName);

                if (req.Path == "/test")
                {
                    bytes = RawPrinter.TestTicket(printer);
                    jobName = "Casher test";
                }
                else
                {
                    string data;
                    if (!fields.TryGetValue("data", out data) || string.IsNullOrEmpty(data))
                    {
                        status = 422;
                        return Json.Obj("ok", false, "error", "data (base64) is required");
                    }
                    try { bytes = Convert.FromBase64String(data); }
                    catch
                    {
                        status = 422;
                        return Json.Obj("ok", false, "error", "data is not valid base64");
                    }
                }

                RawPrinter.Send(printer, bytes, jobName);
                Log.Info("Printed " + bytes.Length + " bytes to '" + printer + "'" + (jobName != null ? " (" + jobName + ")" : ""));
                return Json.Obj("ok", true, "printer", printer, "bytes", bytes.Length);
            }

            status = 404;
            return Json.Obj("ok", false, "error", "not found");
        }

        private string StatusPage()
        {
            var sb = new StringBuilder();
            sb.Append("<!doctype html><html><head><meta charset='utf-8'><title>Casher Print Agent</title>");
            sb.Append("<style>body{font-family:Segoe UI,Arial;background:#1A1A2E;color:#F5F5F5;padding:24px}code{background:#1E2A45;padding:2px 6px;border-radius:4px}li{margin:4px 0}</style></head><body>");
            sb.Append("<h2>").Append(Program.AppName).Append(" v").Append(Program.Version).Append("</h2>");
            sb.Append("<p>Running on <code>http://127.0.0.1:").Append(_port).Append("</code>. The Casher web POS prints through this agent.</p>");
            sb.Append("<h3>Installed printers</h3><ul>");
            foreach (var p in Printers.List())
            {
                sb.Append("<li>").Append(WebUtility.HtmlEncode(p.Name)).Append(p.IsDefault ? " <small>(default)</small>" : "").Append("</li>");
            }
            sb.Append("</ul><p><small>Log: ").Append(WebUtility.HtmlEncode(Log.Folder)).Append("</small></p></body></html>");
            return sb.ToString();
        }

        private static HttpRequest Parse(NetworkStream stream)
        {
            // Read headers byte-by-byte until CRLFCRLF (requests are tiny).
            var headerBytes = new MemoryStream();
            int matched = 0;
            while (matched < 4)
            {
                int b = stream.ReadByte();
                if (b < 0) return null;
                headerBytes.WriteByte((byte)b);
                if ((matched % 2 == 0 && b == '\r') || (matched % 2 == 1 && b == '\n')) matched++;
                else matched = (b == '\r') ? 1 : 0;
                if (headerBytes.Length > 64 * 1024) return null;
            }

            string head = Encoding.ASCII.GetString(headerBytes.ToArray());
            string[] lines = head.Split(new[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);
            if (lines.Length == 0) return null;

            string[] reqLine = lines[0].Split(' ');
            if (reqLine.Length < 2) return null;

            var req = new HttpRequest { Method = reqLine[0].ToUpperInvariant(), Path = reqLine[1] };
            int q = req.Path.IndexOf('?');
            if (q >= 0) req.Path = req.Path.Substring(0, q);

            for (int i = 1; i < lines.Length; i++)
            {
                int c = lines[i].IndexOf(':');
                if (c > 0) req.Headers[lines[i].Substring(0, c).Trim()] = lines[i].Substring(c + 1).Trim();
            }

            int length = 0;
            string cl = req.Header("Content-Length");
            if (cl != null) int.TryParse(cl, out length);
            if (length > 8 * 1024 * 1024) return null; // 8 MB cap

            if (length > 0)
            {
                var body = new byte[length];
                int read = 0;
                while (read < length)
                {
                    int n = stream.Read(body, read, length - read);
                    if (n <= 0) break;
                    read += n;
                }
                req.Body = Encoding.UTF8.GetString(body, 0, read);
            }

            return req;
        }

        private static void WriteResponse(NetworkStream stream, int status, string body, string contentType, HttpRequest req)
        {
            byte[] payload = Encoding.UTF8.GetBytes(body ?? "");
            string origin = req.Header("Origin");

            var sb = new StringBuilder();
            sb.Append("HTTP/1.1 ").Append(status).Append(' ').Append(Reason(status)).Append("\r\n");
            sb.Append("Content-Type: ").Append(contentType).Append("\r\n");
            sb.Append("Content-Length: ").Append(payload.Length).Append("\r\n");
            sb.Append("Connection: close\r\n");
            sb.Append("Cache-Control: no-store\r\n");
            // CORS: any web origin may talk to the loopback agent. Only code
            // running in this user's browser can reach 127.0.0.1 anyway.
            sb.Append("Access-Control-Allow-Origin: ").Append(string.IsNullOrEmpty(origin) ? "*" : origin).Append("\r\n");
            sb.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            sb.Append("Access-Control-Allow-Headers: Content-Type, X-Agent-Token\r\n");
            sb.Append("Access-Control-Max-Age: 600\r\n");
            // Chrome's Private Network Access: an https page calling a
            // loopback http server must be explicitly allowed on preflight.
            if (req.Header("Access-Control-Request-Private-Network") != null)
                sb.Append("Access-Control-Allow-Private-Network: true\r\n");
            sb.Append("\r\n");

            byte[] head = Encoding.ASCII.GetBytes(sb.ToString());
            stream.Write(head, 0, head.Length);
            if (payload.Length > 0 && req.Method != "HEAD") stream.Write(payload, 0, payload.Length);
            stream.Flush();
        }

        private static string Reason(int status)
        {
            switch (status)
            {
                case 200: return "OK";
                case 204: return "No Content";
                case 401: return "Unauthorized";
                case 404: return "Not Found";
                case 422: return "Unprocessable Entity";
                case 500: return "Internal Server Error";
                default: return "OK";
            }
        }
    }

    // ───────────────────────────── Minimal JSON ─────────────────────────────
    // .NET 4.0 has no System.Text.Json; the payloads here are flat objects of
    // strings/numbers/bools, so a tiny hand parser keeps the exe dependency-free.

    internal static class Json
    {
        public static string Str(string s)
        {
            if (s == null) return "null";
            var sb = new StringBuilder("\"");
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else sb.Append(c);
                        break;
                }
            }
            return sb.Append('"').ToString();
        }

        /// <summary>Obj("a", 1, "b", "x") → {"a":1,"b":"x"}</summary>
        public static string Obj(params object[] kv)
        {
            var sb = new StringBuilder("{");
            for (int i = 0; i + 1 < kv.Length; i += 2)
            {
                if (i > 0) sb.Append(',');
                sb.Append(Str((string)kv[i])).Append(':');
                object v = kv[i + 1];
                if (v == null) sb.Append("null");
                else if (v is bool) sb.Append((bool)v ? "true" : "false");
                else if (v is int || v is long || v is double) sb.Append(Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture));
                else sb.Append(Str(v.ToString()));
            }
            return sb.Append('}').ToString();
        }

        /// <summary>Parses a flat JSON object into string values (numbers/bools as their text).</summary>
        public static Dictionary<string, string> ParseFlat(string json)
        {
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            int i = 0;
            SkipWs(json, ref i);
            if (i >= json.Length || json[i] != '{') return result;
            i++;
            while (true)
            {
                SkipWs(json, ref i);
                if (i >= json.Length) break;
                if (json[i] == '}') break;
                if (json[i] == ',') { i++; continue; }
                if (json[i] != '"') break;
                string key = ReadString(json, ref i);
                SkipWs(json, ref i);
                if (i >= json.Length || json[i] != ':') break;
                i++;
                SkipWs(json, ref i);
                if (i >= json.Length) break;

                string value;
                if (json[i] == '"') value = ReadString(json, ref i);
                else if (json[i] == '{' || json[i] == '[') { value = null; SkipNested(json, ref i); }
                else
                {
                    int start = i;
                    while (i < json.Length && json[i] != ',' && json[i] != '}' && !char.IsWhiteSpace(json[i])) i++;
                    value = json.Substring(start, i - start);
                    if (value == "null") value = null;
                }
                result[key] = value;
            }
            return result;
        }

        private static void SkipWs(string s, ref int i)
        {
            while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
        }

        private static void SkipNested(string s, ref int i)
        {
            int depth = 0;
            bool inStr = false;
            for (; i < s.Length; i++)
            {
                char c = s[i];
                if (inStr)
                {
                    if (c == '\\') i++;
                    else if (c == '"') inStr = false;
                    continue;
                }
                if (c == '"') inStr = true;
                else if (c == '{' || c == '[') depth++;
                else if (c == '}' || c == ']')
                {
                    depth--;
                    if (depth == 0) { i++; return; }
                }
            }
        }

        private static string ReadString(string s, ref int i)
        {
            // s[i] == '"'
            i++;
            var sb = new StringBuilder();
            while (i < s.Length)
            {
                char c = s[i++];
                if (c == '"') break;
                if (c == '\\' && i < s.Length)
                {
                    char e = s[i++];
                    switch (e)
                    {
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'u':
                            if (i + 4 <= s.Length)
                            {
                                sb.Append((char)Convert.ToInt32(s.Substring(i, 4), 16));
                                i += 4;
                            }
                            break;
                        default: sb.Append(e); break;
                    }
                }
                else sb.Append(c);
            }
            return sb.ToString();
        }
    }
}
