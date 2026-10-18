#!/usr/bin/env python3
"""BlueZ pairing agent for the ember-test Quickshell bar.

Registers as the default org.bluez.Agent1 and relays every request to the
shell as one JSON object per line on stdout. The shell answers on stdin with
"<id> yes", "<id> no" or "<id> value <text>". Exiting (or the shell dying)
drops the D-Bus connection, which unregisters the agent automatically.
"""
import json
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

AGENT_PATH = "/org/ember/quickshell/agent"
CAPABILITY = "KeyboardDisplay"
REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"

INTROSPECTION = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
    <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
    <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
    <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
    <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
    <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="Cancel"/>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
pending = {}  # request id -> (invocation, kind)
next_id = 0


def emit(message):
    print(json.dumps(message), flush=True)


def device_name(path):
    try:
        reply = bus.call_sync("org.bluez", path, "org.freedesktop.DBus.Properties", "Get",
                              GLib.Variant("(ss)", ("org.bluez.Device1", "Alias")),
                              GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 2000, None)
        return reply.unpack()[0]
    except GLib.Error:
        return path.rsplit("dev_", 1)[-1].replace("_", ":")


def ask(invocation, kind, device, **extra):
    global next_id
    next_id += 1
    pending[next_id] = (invocation, kind)
    emit({"id": next_id, "type": kind, "device": device, "name": device_name(device), **extra})


def on_call(_conn, _sender, _path, _iface, method, params, invocation):
    args = params.unpack()
    if method == "RequestConfirmation":
        ask(invocation, "confirm", args[0], passkey=f"{args[1]:06d}")
    elif method == "RequestAuthorization":
        ask(invocation, "authorize", args[0])
    elif method == "RequestPinCode":
        ask(invocation, "pin", args[0])
    elif method == "RequestPasskey":
        ask(invocation, "passkey", args[0])
    elif method == "DisplayPasskey":
        emit({"id": 0, "type": "display", "device": args[0], "name": device_name(args[0]),
              "passkey": f"{args[1]:06d}", "entered": args[2]})
        invocation.return_value(None)
    elif method == "DisplayPinCode":
        emit({"id": 0, "type": "display", "device": args[0], "name": device_name(args[0]), "passkey": args[1]})
        invocation.return_value(None)
    elif method == "AuthorizeService":
        # Trusted paired devices do not need this callback. Fail closed for
        # untrusted service requests instead of granting access implicitly.
        invocation.return_dbus_error(REJECTED, "Service access requires a trusted device")
    elif method == "Cancel":
        for request_id, (pending_invocation, _kind) in list(pending.items()):
            pending_invocation.return_dbus_error(CANCELED, "Canceled")
            del pending[request_id]
        emit({"id": 0, "type": "cancel"})
        invocation.return_value(None)
    else:  # Release
        invocation.return_value(None)


def on_stdin(source, _condition):
    line = source.readline()
    if not line:
        loop.quit()
        return False
    parts = line.strip().split(" ", 2)
    if len(parts) < 2 or not parts[0].isdigit():
        return True
    entry = pending.pop(int(parts[0]), None)
    if entry is None:
        return True
    invocation, kind = entry
    answer = parts[1]
    value = parts[2] if len(parts) > 2 else ""
    if answer == "no":
        invocation.return_dbus_error(REJECTED, "Rejected by user")
    elif kind == "pin" and value:
        invocation.return_value(GLib.Variant("(s)", (value,)))
    elif kind == "passkey" and value.isdigit():
        invocation.return_value(GLib.Variant("(u)", (int(value),)))
    elif kind in ("confirm", "authorize"):
        invocation.return_value(None)
    else:
        invocation.return_dbus_error(REJECTED, "No value given")
    return True


def register(*_):
    try:
        for method, args in (("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY))),
                             ("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)))):
            bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", method, args,
                          None, Gio.DBusCallFlags.NONE, 5000, None)
        emit({"id": 0, "type": "ready"})
    except GLib.Error as error:
        if "AlreadyExists" not in error.message:
            print(f"agent registration failed: {error.message}", file=sys.stderr, flush=True)


node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
bus.register_object(AGENT_PATH, node.interfaces[0], on_call, None, None)
# Re-register whenever bluetoothd (re)appears on the bus.
Gio.bus_watch_name_on_connection(bus, "org.bluez", Gio.BusNameWatcherFlags.NONE, register, None)
GLib.io_add_watch(sys.stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_stdin)
loop = GLib.MainLoop()
loop.run()
