import server

print("--- Testing MuMu Screen Sniffer on Ports ---")
for port in [16384, 7555, 5555, 16416]:
    res = server._capture_and_compress_sync(port)
    if res:
        print(f"[SUCCESS] Port {port}: Captured {len(res)} bytes JPEG")
    else:
        print(f"[FAILED] Port {port}")
