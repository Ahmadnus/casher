@echo off
REM Builds CasherPrintAgent.exe with the C# compiler bundled in .NET Framework 4.x
REM (present on every Windows 8/10/11 install and on Windows 7 with .NET 4 installed).
REM No Visual Studio or SDK required.
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo csc.exe not found - install .NET Framework 4.x
  exit /b 1
)
"%CSC%" /nologo /target:winexe /optimize+ /platform:anycpu /out:CasherPrintAgent.exe ^
  /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll ^
  /win32manifest:app.manifest CasherPrintAgent.cs
if errorlevel 1 exit /b 1
echo Built CasherPrintAgent.exe
