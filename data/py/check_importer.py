"""Checks what the gear importer needs: Python, Npcap, and capture interfaces. Run with check-importer.cmd."""
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ok = True


def report(passed, label, detail=""):
    global ok
    ok = ok and passed
    print(("[ OK ] " if passed else "[FAIL] ") + label + (": " + detail if detail else ""))


report(sys.version_info >= (3, 4), "Python", sys.version.split()[0] + " at " + sys.executable)

npcap_dll = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "Npcap", "wpcap.dll")
report(os.path.exists(npcap_dll), "Npcap installed", npcap_dll if os.path.exists(npcap_dll) else "not found, install it from https://npcap.com/#download")

try:
    from scapy.all import conf, get_working_ifaces
    report(True, "Bundled scapy", conf.version)
    report(bool(conf.use_pcap), "scapy using Npcap", "yes" if conf.use_pcap else "no libpcap provider, Npcap missing or not loaded")
    ifaces = get_working_ifaces()
    report(len(ifaces) > 0, "Capture interfaces", str(len(ifaces)))
    for iface in ifaces:
        print("         - " + str(iface.description or iface.name) + ("  " + iface.ip if iface.ip else ""))
except Exception as e:
    report(False, "Bundled scapy", repr(e))

# The importer uploads captured data here for decoding; only check that it answers
try:
    with urllib.request.urlopen("https://krivpfvxi0.execute-api.us-west-2.amazonaws.com/dev", timeout=15) as r:
        status = r.status
except urllib.error.HTTPError as e:
    status = e.code
except Exception as e:
    status = repr(e)
report(isinstance(status, int), "Decoding server reachable", "HTTP " + str(status))

print()
print("All checks passed." if ok else "Some checks failed, see above.")
