"""Checks what the gear importer needs: Python, Npcap, capture interfaces and the decoding server.

Run with scripts/check-importer.cmd or from the optimizer's Tools menu.
"""
import logging
import os
import sys
import unicodedata
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# scapy prints its own warning when Npcap is missing; the checks below explain it instead
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)

ok = True


def pad(text, width):
    # Chinese characters take two columns in the console
    used = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)
    return text + " " * max(width - used, 1)


def report(passed, label, detail=""):
    global ok
    ok = ok and passed
    print("  {}  {}{}".format("√" if passed else "×", pad(label, 12), detail))


print()
print("  Fribbels 配装器 · 导入环境检测")
print("  " + "-" * 40)

report(sys.version_info >= (3, 4), "Python", sys.version.split()[0] + "  (" + sys.executable + ")")

npcap_dll = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "Npcap", "wpcap.dll")
report(os.path.exists(npcap_dll), "Npcap", "已安装" if os.path.exists(npcap_dll) else "未安装，请从 https://npcap.com/#download 下载安装（需要管理员权限）")

ifaces = []
try:
    from scapy.all import conf, get_working_ifaces
    report(bool(conf.use_pcap), "抓包组件", "scapy " + conf.version + ("，已接入 Npcap" if conf.use_pcap else "，没有接入 Npcap"))
    ifaces = get_working_ifaces()
    report(len(ifaces) > 0, "可用网卡", "{} 块".format(len(ifaces)))
except Exception as e:
    report(False, "抓包组件", repr(e))
for iface in ifaces:
    print("                 · " + str(iface.description or iface.name) + ("  " + iface.ip if iface.ip else ""))

# The importer uploads captured data here for decoding; only check that it answers
try:
    with urllib.request.urlopen("https://krivpfvxi0.execute-api.us-west-2.amazonaws.com/dev", timeout=15) as r:
        status = r.status
except urllib.error.HTTPError as e:
    status = e.code
except Exception as e:
    status = repr(e)
report(isinstance(status, int), "解码服务器", "可以访问" if isinstance(status, int) else "无法访问（" + str(status) + "）")

print("  " + "-" * 40)
print("  全部正常，可以使用自动导入。" if ok else "  有检查项没通过，请按上面的提示处理。")
print()
