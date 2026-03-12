using Avalonia;
using Jellyfin2Samsung.Extensions;
using Jellyfin2Samsung.Helpers;
using System;
using System.Diagnostics;
using System.IO;

namespace Jellyfin2Samsung
{
    internal sealed class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            // Register trace listener BEFORE Avalonia starts
            var logFolder = AppSettings.LogPath;
            var dtg = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss-fff");
            var logFile = Path.Combine(logFolder, $"debug_{dtg}.log");

            Trace.Listeners.Add(new FileTraceListener(logFile));
            Trace.AutoFlush = true;


            BuildAvaloniaApp()
                .StartWithClassicDesktopLifetime(args);
        }

        public static AppBuilder BuildAvaloniaApp()
            => AppBuilder.Configure<App>()
                .UsePlatformDetect()
                .WithInterFont()
                .LogToTrace();

    }
}
