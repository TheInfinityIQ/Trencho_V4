using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

// Owns only this check's headless Godot process. It attaches the job immediately
// after Process.Start; the brief native startup interval precedes the job limits.
// This is deliberately not a general launcher for programs that spawn children
// during startup. The selected Godot import/CI runner runs in this one process.
public static class WindowsCurrentCheckProcess
{
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinWorkingSet, MaxWorkingSet;
        public uint ActiveProcesses;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters {
        public ulong ReadOperations, WriteOperations, OtherOperations, ReadBytes, WriteBytes, OtherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic;
        public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)] struct CpuLimits { public uint Flags, Rate; }
    [StructLayout(LayoutKind.Sequential)] struct MemoryStatus {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPage, AvailablePage, TotalVirtual, AvailableVirtual, Extended;
    }
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr security, string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int info, IntPtr data, uint size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int info, out ExtendedLimits limits, uint size, IntPtr returned);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetProcessAffinityMask(IntPtr process, out UIntPtr affinity, out UIntPtr system);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);

    static void SetLimits<T>(IntPtr job, int info, T value) where T : struct {
        int size = Marshal.SizeOf<T>();
        IntPtr data = Marshal.AllocHGlobal(size);
        try {
            Marshal.StructureToPtr(value, data, false);
            if (!SetInformationJobObject(job, info, data, (uint)size)) throw new Win32Exception();
        } finally { Marshal.FreeHGlobal(data); }
    }
    static ulong FreeMemory() {
        var status = new MemoryStatus { Length = (uint)Marshal.SizeOf<MemoryStatus>() };
        if (!GlobalMemoryStatusEx(ref status)) throw new Win32Exception();
        return status.AvailablePhysical;
    }

    public static int Run(string engine, string[] arguments, string directory, string log, int timeoutMs) {
        if (timeoutMs < 1 || timeoutMs > 30000) throw new ArgumentOutOfRangeException(nameof(timeoutMs));
        if (FreeMemory() < 2048UL*1024*1024) throw new InvalidOperationException("Local check needs 2 GB free memory; use GitHub while memory is constrained.");
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) throw new Win32Exception();
        Process process = null;
        bool started = false;
        var timer = Stopwatch.StartNew();
        object outputLock = new object();
        using (var output = new StreamWriter(log, false)) {
            try {
                UIntPtr allowed, system;
                if (!GetProcessAffinityMask(Process.GetCurrentProcess().Handle, out allowed, out system)) throw new Win32Exception();
                ulong mask = 0;
                int count = 0;
                for (int bit=0; bit<64 && count<2; bit++) {
                    ulong candidate = 1UL << bit;
                    if ((allowed.ToUInt64() & candidate) != 0) { mask |= candidate; count++; }
                }
                SetLimits(job, 9, new ExtendedLimits {
                    Basic = new BasicLimits { Flags = 0x2000|0x200|0x10|0x20|0x8, ActiveProcesses=1, Affinity=(UIntPtr)mask, Priority=0x40 },
                    JobMemory = (UIntPtr)(1024UL*1024*1024)
                });
                SetLimits(job, 15, new CpuLimits { Flags=0x1|0x4, Rate=1500 });
                var start = new ProcessStartInfo(engine) {
                    WorkingDirectory=directory, UseShellExecute=false, CreateNoWindow=true,
                    RedirectStandardOutput=true, RedirectStandardError=true
                };
                foreach (string argument in arguments) start.ArgumentList.Add(argument);
                process = new Process { StartInfo=start };
                process.OutputDataReceived += (sender, data) => { if (data.Data != null) lock(outputLock) output.WriteLine(data.Data); };
                process.ErrorDataReceived += (sender, data) => { if (data.Data != null) lock(outputLock) output.WriteLine(data.Data); };
                started = process.Start();
                if (!started) throw new InvalidOperationException("Engine did not start.");
                if (!AssignProcessToJobObject(job, process.Handle)) throw new Win32Exception();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                while (!process.WaitForExit(100)) {
                    if (timer.ElapsedMilliseconds >= timeoutMs || FreeMemory() < 1024UL*1024*1024) {
                        if (!TerminateJobObject(job, 124)) process.Kill(true);
                        if (!process.WaitForExit(2000)) throw new InvalidOperationException("Owned engine did not stop after its deadline.");
                        lock(outputLock) output.WriteLine("LOCAL_CHECK_STOPPED: deadline or free-memory reserve reached.");
                        return 124;
                    }
                }
                process.WaitForExit(); // Drain redirected output before closing its writer.
                ExtendedLimits measured;
                if (!QueryInformationJobObject(job, 9, out measured, (uint)Marshal.SizeOf<ExtendedLimits>(), IntPtr.Zero)) throw new Win32Exception();
                lock(outputLock) output.WriteLine("LOCAL_CHECK_PROCESS: elapsed_ms="+timer.ElapsedMilliseconds+" peak_job_commit_mb="+(measured.PeakJobMemory.ToUInt64()/1024/1024)+" exit="+process.ExitCode);
                return process.ExitCode;
            } finally {
                // Never find/stop another Godot process or the human editor.
                try {
                    if (process != null && started && !process.HasExited) {
                        if (!TerminateJobObject(job,124)) process.Kill(true);
                        process.WaitForExit(2000);
                    }
                } finally {
                    CloseHandle(job); // Kill-on-close remains effective even if cleanup throws.
                    if (process != null) process.Dispose();
                }
            }
        }
    }
}
