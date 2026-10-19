"""Records where game traffic shows up during a login, to diagnose importer failures (e.g. with game accelerators).

Run with diagnose-importer.cmd. Captures TCP and UDP on every interface, including loopback and adapters that appear
while it runs. Only connection addresses, ports, sizes and the first 16 bytes of the first few packets of each
connection are kept. Nothing is uploaded; the report is written to a local text file.
"""
import argparse
import ctypes
import datetime
import os
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scapy.all import conf, AsyncSniffer, get_working_ifaces, IP, IPv6, TCP, UDP, Raw  # noqa: E402

GAME_PORTS = (3333, 5222)
LARGE_BYTES = 50 * 1024
SAMPLE_PACKETS = 3
SAMPLE_BYTES = 16

lock = threading.Lock()
flows = {}
sniffers = {}
interfaces = []
start_time = time.time()


def handle(iface_label, packet):
    if IP in packet:
        src, dst = packet[IP].src, packet[IP].dst
    elif IPv6 in packet:
        src, dst = packet[IPv6].src, packet[IPv6].dst
    else:
        return
    if TCP in packet:
        proto, sport, dport = "TCP", packet[TCP].sport, packet[TCP].dport
    elif UDP in packet:
        proto, sport, dport = "UDP", packet[UDP].sport, packet[UDP].dport
    else:
        return
    payload = bytes(packet[Raw].load) if Raw in packet else b""

    key = (iface_label, proto, src, sport, dst, dport)
    with lock:
        flow = flows.get(key)
        if flow is None:
            flow = flows[key] = {"packets": 0, "bytes": 0, "first": time.time() - start_time, "samples": []}
        flow["packets"] += 1
        flow["bytes"] += len(payload)
        if proto == "TCP" and payload and len(flow["samples"]) < SAMPLE_PACKETS:
            flow["samples"].append(payload[:SAMPLE_BYTES].hex())


def start_new_interfaces():
    for iface in get_working_ifaces():
        if iface.network_name in sniffers:
            continue
        label = iface.description or iface.name
        try:
            sniffer = AsyncSniffer(iface=iface, filter="tcp or udp", store=False,
                                   prn=lambda p, label=label: handle(label, p))
            sniffer.start()
            sniffers[iface.network_name] = sniffer
            status = "capturing"
        except Exception as e:
            sniffers[iface.network_name] = None
            status = "failed: " + repr(e)[:120]
        interfaces.append((time.time() - start_time, label, iface.ip or "", status))


def watch_interfaces(stop):
    # Accelerators may create their virtual adapter only after the game starts
    while not stop.wait(2.0):
        try:
            conf.ifaces.reload()
            start_new_interfaces()
        except Exception:
            pass


def documents_folder():
    buf = ctypes.create_unicode_buffer(260)
    if ctypes.windll.shell32.SHGetFolderPathW(None, 5, None, 0, buf) == 0:
        return buf.value
    return os.path.expanduser("~")


def fmt_flow(key, flow):
    iface, proto, src, sport, dst, dport = key
    line = "  [{}] {} {}:{} -> {}:{}  packets={} bytes={} first_seen={:.0f}s".format(
        iface, proto, src, sport, dst, dport, flow["packets"], flow["bytes"], flow["first"])
    if flow["samples"]:
        line += "\n      first bytes: " + " | ".join(flow["samples"])
    return line


def is_known_protocol(flow):
    """True for flows that start like HTTP, JSON or TLS, which the game protocol is not."""
    if not flow["samples"]:
        return False
    head = bytes.fromhex(flow["samples"][0])
    if head.startswith((b"GET ", b"POST", b"PUT ", b"HEAD", b"HTTP/", b"{", b"[")):
        return True
    return len(head) >= 2 and head[0] in (0x14, 0x15, 0x16, 0x17) and head[1] == 0x03


def build_report(duration):
    with lock:
        items = list(flows.items())
    tcp = sorted([kv for kv in items if kv[0][1] == "TCP"], key=lambda kv: -kv[1]["bytes"])
    udp = sorted([kv for kv in items if kv[0][1] == "UDP"], key=lambda kv: -kv[1]["bytes"])
    game = [kv for kv in tcp if kv[0][3] in GAME_PORTS or kv[0][5] in GAME_PORTS]
    loopback_large = [kv for kv in tcp if "Loopback" in kv[0][0] and kv[1]["bytes"] >= LARGE_BYTES
                      and not is_known_protocol(kv[1])]
    udp_large = [kv for kv in udp if kv[1]["bytes"] >= LARGE_BYTES and "Loopback" not in kv[0][0]]
    late_ifaces = [i for i in interfaces if i[0] > 1]

    lines = [
        "Fribbels importer capture diagnostic",
        "Time: {}  Duration: {:.0f}s  Python {}  scapy {}".format(
            datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), duration, sys.version.split()[0], conf.version),
        "Contains connection addresses, ports, sizes and the first {} bytes of the first {} packets per TCP "
        "connection. Review before sharing.".format(SAMPLE_BYTES, SAMPLE_PACKETS),
        "",
        "== Interfaces (seconds after start, name, IP, status)",
    ]
    lines += ["  {:>4.0f}s  {}  {}  {}".format(*i) for i in interfaces]

    lines += ["", "== Hints"]
    game_large = [kv for kv in game if kv[1]["bytes"] >= LARGE_BYTES]
    if game_large:
        where = sorted(set(kv[0][0] for kv in game_large))
        lines.append("  Game ports {} carried large traffic on: {}.".format(GAME_PORTS, ", ".join(where)))
        late = [i[1] for i in late_ifaces if i[1] in where]
        if late:
            lines.append("  That interface appeared after capture started ({}); the importer must pick up new "
                         "interfaces.".format(", ".join(late)))
        else:
            lines.append("  The standard importer should see this traffic.")
    else:
        lines.append("  No large traffic on game ports {}.".format(GAME_PORTS))
        if loopback_large:
            lines.append("  Large non-HTTP/TLS TCP traffic on loopback (possible accelerator local proxy): " +
                         ", ".join(sorted(set("{}->{}".format(k[3], k[5]) for k, _ in loopback_large))))
        if udp_large:
            lines.append("  Large UDP traffic (possible encrypted accelerator tunnel, unreadable on this PC): " +
                         ", ".join("{}:{} -> {}:{}".format(k[2], k[3], k[4], k[5]) for k, _ in udp_large[:5]))
        if not loopback_large and not udp_large:
            lines.append("  No large game-like traffic seen. Was the game started and logged into the lobby while "
                         "this ran?")

    lines += ["", "== TCP connections on game ports {}".format(GAME_PORTS)]
    lines += [fmt_flow(k, v) for k, v in game] or ["  none"]
    lines += ["", "== Largest TCP flows (one direction each)"]
    lines += [fmt_flow(k, v) for k, v in tcp[:25]] or ["  none"]
    lines += ["", "== Largest UDP flows"]
    lines += ["  [{}] UDP {}:{} -> {}:{}  packets={} bytes={}".format(
        k[0], k[2], k[3], k[4], k[5], v["packets"], v["bytes"]) for k, v in udp[:15]] or ["  none"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=int, default=0, help="stop after this many seconds instead of on Enter")
    parser.add_argument("--out", default="", help="report path (default: Documents\\FribbelsOptimizerSaves)")
    parser.add_argument("--out-dir", default="", help="folder for the report, named by time")
    args = parser.parse_args()

    start_new_interfaces()
    capturing = sum(1 for s in sniffers.values() if s)
    if not capturing:
        print("No network interface can be captured. Install Npcap from https://npcap.com/#download and try again.")
        print("没有可以抓包的网卡。请先安装 Npcap（https://npcap.com/#download）再运行。")
        sys.exit(1)
    stop = threading.Event()
    threading.Thread(target=watch_interfaces, args=(stop,), daemon=True).start()

    print("Capturing on {} interfaces. / 正在抓取 {} 块网卡。".format(capturing, capturing))
    if args.seconds:
        time.sleep(args.seconds)
    else:
        print("Now start the accelerator if you use one, open Epic Seven and log into the lobby.")
        print("Press Enter when you are in the lobby (stops automatically after 5 minutes).")
        print("现在打开加速器（如果你用的话），启动第七史诗并进入大厅。")
        print("进入大厅后按回车（5 分钟后会自动结束）。")
        done = threading.Event()
        threading.Thread(target=lambda: (sys.stdin.readline(), done.set()), daemon=True).start()
        done.wait(300)

    stop.set()
    duration = time.time() - start_time
    for sniffer in sniffers.values():
        if sniffer:
            try:
                sniffer.stop()
            except Exception:
                pass

    out = args.out
    if not out:
        folder = args.out_dir or os.path.join(documents_folder(), "FribbelsOptimizerSaves")
        os.makedirs(folder, exist_ok=True)
        out = os.path.join(folder, "importer-diagnose-{}.txt".format(datetime.datetime.now().strftime("%Y%m%d-%H%M%S")))
    report = build_report(duration)
    with open(out, "w", encoding="utf-8") as f:
        f.write(report)
    print()
    print(report[report.index("== Hints"):report.index("== TCP connections")])
    print("Report saved to / 报告已保存到: " + out)


if __name__ == "__main__":
    main()
