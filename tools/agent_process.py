"""Run one owned process tree with a deadline; never kill unrelated applications."""
import ctypes
import os
from pathlib import Path
import shutil
import subprocess
import time


class OwnedProcess:
    """Windows children start suspended and enter a kill-on-close job before running."""

    def __init__(self, argv, cwd, stdin_path, stdout_path, stderr_path):
        self.files = []
        self.job = self.handle = None
        self.process = None
        try:
            argv = list(argv)
            if '/' in argv[0] or '\\' in argv[0]:
                executable = Path(argv[0])
                argv[0] = str((Path(cwd) / executable).resolve())
            else:
                executable = shutil.which(argv[0])
                if not executable:
                    raise FileNotFoundError(f'Executable not found on PATH: {argv[0]}')
                argv[0] = executable
            self.argv = argv
            for path, mode in ((stdin_path, 'rb'), (stdout_path, 'wb'), (stderr_path, 'wb')):
                self.files.append(open(path, mode))
            if os.name == 'nt':
                self._windows(argv, cwd)
            else:
                self.process = subprocess.Popen(argv, cwd=cwd, stdin=self.files[0],
                                                stdout=self.files[1], stderr=self.files[2],
                                                start_new_session=True)
                self.pid = self.process.pid
        except BaseException:
            self.close()
            raise

    def _windows(self, argv, cwd):
        import _winapi
        import msvcrt
        from ctypes import wintypes as w

        class Basic(ctypes.Structure):
            _fields_ = [('process_time', ctypes.c_longlong), ('job_time', ctypes.c_longlong),
                        ('flags', w.DWORD), ('min_working', ctypes.c_size_t),
                        ('max_working', ctypes.c_size_t), ('active', w.DWORD),
                        ('affinity', ctypes.c_size_t), ('priority', w.DWORD), ('scheduling', w.DWORD)]

        class IO(ctypes.Structure):
            _fields_ = [(name, ctypes.c_ulonglong) for name in
                        ('reads', 'writes', 'other', 'read_bytes', 'write_bytes', 'other_bytes')]

        class Extended(ctypes.Structure):
            _fields_ = [('basic', Basic), ('io', IO), ('process_memory', ctypes.c_size_t),
                        ('job_memory', ctypes.c_size_t), ('peak_process', ctypes.c_size_t),
                        ('peak_job', ctypes.c_size_t)]

        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, w.LPCWSTR]
        kernel.CreateJobObjectW.restype = w.HANDLE
        kernel.SetInformationJobObject.argtypes = [w.HANDLE, ctypes.c_int, ctypes.c_void_p, w.DWORD]
        kernel.AssignProcessToJobObject.argtypes = [w.HANDLE, w.HANDLE]
        kernel.TerminateJobObject.argtypes = [w.HANDLE, w.UINT]
        kernel.CloseHandle.argtypes = [w.HANDLE]
        kernel.ResumeThread.argtypes = [w.HANDLE]
        kernel.ResumeThread.restype = w.DWORD
        self.kernel = kernel
        self.job = kernel.CreateJobObjectW(None, None)
        if not self.job:
            raise ctypes.WinError(ctypes.get_last_error())
        info = Extended()
        info.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not kernel.SetInformationJobObject(self.job, 9, ctypes.byref(info), ctypes.sizeof(info)):
            raise ctypes.WinError(ctypes.get_last_error())
        startup = subprocess.STARTUPINFO()
        startup.dwFlags = subprocess.STARTF_USESTDHANDLES | subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        handles = [msvcrt.get_osfhandle(f.fileno()) for f in self.files]
        startup.hStdInput, startup.hStdOutput, startup.hStdError = handles
        inherited = [os.get_handle_inheritable(h) for h in handles]
        thread = None
        try:
            for h in handles:
                os.set_handle_inheritable(h, True)
            self.handle, thread, self.pid, _ = _winapi.CreateProcess(
                argv[0], subprocess.list2cmdline(argv), None, None, True,
                0x00000004 | 0x08000000, None, str(cwd), startup)  # SUSPENDED | NO_WINDOW
            if not kernel.AssignProcessToJobObject(self.job, self.handle):
                _winapi.TerminateProcess(self.handle, 125)
                raise ctypes.WinError(ctypes.get_last_error())
            if kernel.ResumeThread(thread) == 0xFFFFFFFF:
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            if thread is not None:
                _winapi.CloseHandle(thread)
            for h, was_inherited in zip(handles, inherited):
                os.set_handle_inheritable(h, was_inherited)

    def poll(self):
        if os.name != 'nt':
            return self.process.poll()
        import _winapi
        return (_winapi.GetExitCodeProcess(self.handle)
                if _winapi.WaitForSingleObject(self.handle, 0) == 0 else None)

    def terminate(self):
        if os.name == 'nt':
            if self.job:
                self.kernel.TerminateJobObject(self.job, 124)
        elif self.process:
            import signal
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

    def close(self):
        # Closing the job also removes children left behind by an exited parent.
        if os.name == 'nt':
            if self.job:
                self.kernel.CloseHandle(self.job)
                self.job = None
            if self.handle:
                import _winapi
                _winapi.CloseHandle(self.handle)
                self.handle = None
        elif self.process:
            self.terminate()
            self.process.wait(timeout=3)
            self.process = None
        for f in self.files:
            f.close()

    def run(self, timeout, stopped, heartbeat):
        started = time.monotonic()
        reason = None
        try:
            while self.poll() is None:
                heartbeat()
                if stopped():
                    reason = 'stopped'
                    break
                if time.monotonic() - started >= timeout:
                    reason = 'timeout'
                    break
                time.sleep(0.05)
            if reason:
                self.terminate()
                deadline = time.monotonic() + 3
                while self.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                if self.poll() is None:
                    raise RuntimeError('Owned process did not stop within the cleanup grace period.')
            return self.poll(), reason
        finally:
            self.close()
