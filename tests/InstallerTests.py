"""Exercise postinstall control flow with every system command replaced by a stub."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).resolve().parents[1] / "packaging/scripts/postinstall").read_text()
with tempfile.TemporaryDirectory(prefix="AstraCreate installer tests ") as directory:
    root = Path(directory)
    log = root / "calls.jsonl"
    stub = root / "stub.py"
    stub.write_text('''#!/usr/bin/env python3
import json, os, sys
kind, *args = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps([kind, *args]) + "\\n")
if kind == "stat":
    print(os.environ.get("TEST_USER", "testuser"))
elif kind == "id":
    print(os.environ.get("TEST_UID", "501"))
elif kind == "launchctl":
    tool = args[6]
    step = "enable" if tool.endswith("pluginkit") and "-e" in args else tool.rsplit("/", 1)[-1]
    if step == os.environ.get("TEST_FAIL"):
        sys.exit(7)
''')
    stub.chmod(0o755)
    for command in ("/usr/bin/stat", "/usr/bin/id", "/bin/launchctl"):
        source = source.replace(command, f"'{stub}' {Path(command).name}")
    script = root / "postinstall"
    script.write_text(source)

    def run(*, user="testuser", uid="501", fail="", volume="/"):
        log.write_text("")
        env = {**os.environ, "TEST_CALLS": str(log), "TEST_USER": user,
               "TEST_UID": uid, "TEST_FAIL": fail}
        result = subprocess.run(["/bin/zsh", str(script), "pkg", "/", volume],
                                env=env, text=True, capture_output=True, check=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, [call for call in calls if call[0] == "launchctl"], calls

    result, calls, _ = run()
    assert len(calls) == 4, calls
    for call in calls:
        assert call[1:7] == ["asuser", "501", "/usr/bin/sudo", "-H", "-u", "testuser"], call
    assert calls[0][7].endswith("lsregister")
    assert calls[1][8] == "-a"
    assert calls[2][8:11] == ["-e", "use", "-i"]
    assert calls[3][7:] == ["/usr/bin/killall", "-u", "testuser", "Finder"]
    assert "activation requested" in result.stdout
    for user in ("root", "loginwindow", "_mbsetupuser", ""):
        result, calls, _ = run(user=user)
        assert not calls and "registration deferred" in result.stderr
    for uid in ("0", "500", "invalid"):
        result, calls, _ = run(uid=uid)
        assert not calls and "registration deferred" in result.stderr
    result, calls, all_calls = run(volume="/Volumes/Other")
    assert not all_calls and "another volume" in result.stderr
    for step, expected_count in (("lsregister", 1), ("pluginkit", 2), ("enable", 3)):
        result, calls, _ = run(fail=step)
        assert len(calls) == expected_count, (step, calls)
        assert "failed" in result.stderr and "activation requested" not in result.stdout
    result, calls, _ = run(fail="killall")
    assert len(calls) == 4 and "not restarted" in result.stderr
print("Passed installer user context, headless/other-volume skips and failure handling (all system actions stubbed).")
