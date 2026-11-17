"""Use the existing libimobiledevice USB installation proxy for this app only.

No pairing, global settings or arbitrary application removal. The lifecycle
controller checkpoints an uninstall before invoking this bounded child process.
"""
import argparse
import ctypes as C
import ctypes.util
import json
import plistlib
import re
from pathlib import Path

BUNDLE = 'io.ozio.chatgptx.chat.legacy'


def container_path(path):
    assert isinstance(path, str) and re.fullmatch(r'(?:/private)?/var/mobile/Applications/[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}', path), 'Invalid own container'
    return '/private'+path if path.startswith('/var/') else path


class Proxy:
    def __init__(self, udid):
        assert re.fullmatch(r'[a-fA-F0-9-]{24,64}', udid)
        self.device = C.c_void_p()
        self.lockdown = C.c_void_p()
        self.service = C.c_void_p()
        self.client = C.c_void_p()
        def library(name):
            found=C.util.find_library(name)
            if found: return found
            # Apple's bundled Python does not search the Apple Silicon
            # Homebrew prefix, even when its CLI tools are already on PATH.
            candidate=Path('/opt/homebrew/lib')/('lib'+name+'.dylib')
            return str(candidate) if candidate.is_file() else None
        device_library = library('imobiledevice-1.0')
        plist_library = library('plist-2.0')
        assert device_library and plist_library, 'Existing libimobiledevice/libplist required'
        self.lib = C.CDLL(device_library)
        self.plist = C.CDLL(plist_library)
        p, pp = C.c_void_p, C.POINTER(C.c_void_p)
        declarations = {
            'idevice_new_with_options': ([pp, C.c_char_p, C.c_int], C.c_int),
            'idevice_free': ([p], C.c_int),
            'lockdownd_client_new_with_handshake': ([p, pp, C.c_char_p], C.c_int),
            'lockdownd_client_free': ([p], C.c_int),
            'lockdownd_start_service': ([p, C.c_char_p, pp], C.c_int),
            'lockdownd_service_descriptor_free': ([p], C.c_int),
            'instproxy_client_new': ([p, p, pp], C.c_int),
            'instproxy_client_free': ([p], C.c_int),
            'instproxy_lookup': ([p, C.POINTER(C.c_char_p), p, pp], C.c_int),
            'instproxy_browse': ([p, p, pp], C.c_int),
            'instproxy_uninstall': ([p, C.c_char_p, p, p, p], C.c_int),
        }
        for name, (args, result) in declarations.items():
            function = getattr(self.lib, name)
            function.argtypes, function.restype = args, result
        for name, args, result in [
            ('plist_new_dict', [], p), ('plist_new_array', [], p),
            ('plist_new_string', [C.c_char_p], p),
            ('plist_dict_set_item', [p, C.c_char_p, p], C.c_int),
            ('plist_array_append_item', [p, p], C.c_int),
            ('plist_free', [p], None), ('plist_mem_free', [p], None),
            ('plist_to_xml', [p, pp, C.POINTER(C.c_uint32)], C.c_int),
        ]:
            function = getattr(self.plist, name)
            function.argtypes, function.restype = args, result
        try:
            self.check(self.lib.idevice_new_with_options(C.byref(self.device), udid.encode(), 2))  # USBMUX only
            self.check(self.lib.lockdownd_client_new_with_handshake(self.device, C.byref(self.lockdown), b'ChatGPT X'))
            self.check(self.lib.lockdownd_start_service(self.lockdown, b'com.apple.mobile.installation_proxy', C.byref(self.service)))
            self.check(self.lib.instproxy_client_new(self.device, self.service, C.byref(self.client)))
        except BaseException:
            self.close()
            raise

    @staticmethod
    def check(code):
        if code:
            raise RuntimeError('installation_proxy_error_'+str(code))

    def decode(self, node):
        pointer, size = C.c_void_p(), C.c_uint32()
        try:
            self.check(self.plist.plist_to_xml(node, C.byref(pointer), C.byref(size)))
            assert pointer and size.value <= 16*1024*1024, 'Installation metadata limit'
            return plistlib.loads(C.string_at(pointer, size.value))
        finally:
            if pointer:
                self.plist.plist_mem_free(pointer)

    def apps(self):
        options, result = self.plist.plist_new_dict(), C.c_void_p()
        try:
            self.check(self.plist.plist_dict_set_item(options, b'ApplicationType', self.plist.plist_new_string(b'User')))
            attributes = self.plist.plist_new_array()
            for key in [b'CFBundleIdentifier', b'CFBundleVersion', b'Path']:
                self.check(self.plist.plist_array_append_item(attributes, self.plist.plist_new_string(key)))
            self.check(self.plist.plist_dict_set_item(options, b'ReturnAttributes', attributes))
            self.check(self.lib.instproxy_browse(self.client, options, C.byref(result)))
            rows = self.decode(result)
            assert isinstance(rows, list)
            return {row['CFBundleIdentifier']: {key: row.get(key) for key in ['CFBundleVersion', 'Path']} for row in rows}
        finally:
            if result:
                self.plist.plist_free(result)
            self.plist.plist_free(options)

    def lookup(self):
        # Browse works on the accepted iOS6 installation proxy as well as newer
        # library versions, and requests only three public registration fields.
        return self.apps().get(BUNDLE)

    def uninstall(self, expected_container):
        expected_container = container_path(expected_container)
        registered = self.lookup()
        assert registered and registered['Path'].endswith('/ChatGPTX.app'), 'Own application missing'
        assert container_path(registered['Path'].removesuffix('/ChatGPTX.app')) == expected_container, 'Own registered container changed'
        # NULL callback means synchronous completion, per the installed header.
        # This call is issued once; errors must be reconciled, never retried.
        self.check(self.lib.instproxy_uninstall(self.client, BUNDLE.encode(), None, None, None))
        assert self.lookup() is None, 'Own registration remains after uninstall'
        return {'bundleID': BUNDLE, 'uninstalled': True}

    def close(self):
        for pointer, free in [(self.client, 'instproxy_client_free'),
                              (self.service, 'lockdownd_service_descriptor_free'),
                              (self.lockdown, 'lockdownd_client_free'), (self.device, 'idevice_free')]:
            if pointer:
                getattr(self.lib, free)(pointer)
                pointer.value = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', required=True)
    parser.add_argument('command', choices=['lookup', 'apps', 'uninstall'])
    parser.add_argument('--expected-container')
    args = parser.parse_args()
    if args.command == 'uninstall':
        container_path(args.expected_container)
    with Proxy(args.udid) as proxy:
        value = proxy.uninstall(args.expected_container) if args.command == 'uninstall' else getattr(proxy, args.command)()
        print(json.dumps(value, sort_keys=True))
