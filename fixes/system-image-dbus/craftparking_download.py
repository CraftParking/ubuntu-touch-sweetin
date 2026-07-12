"""CraftParking background update downloader.

Runs inside system-image-dbus (root, bus-activated, persistent) rather than
inside the Settings app's own process - a QML page (and the whole
system-settings process) can come and go, get backgrounded, or get its
network throttled while unfocused, none of which should kill an in-progress
multi-GB download. This module knows nothing about D-Bus itself; dbus.py
wires it up and marshals the callbacks onto the GLib main loop.
"""

import os
import hashlib
import logging
import threading
import urllib.request

log = logging.getLogger('systemimage')

# Hardcoded, not os.path.expanduser('~') - this module runs inside the
# system-image-dbus service, which executes as root, so '~' would resolve
# to /root, not phablet's home. craftparking_apply_update() in apply.py
# only accepts source paths under /home/phablet/, so this has to match.
_DOWNLOAD_DIR = '/home/phablet/.cache/craftparking-update'
_DOWNLOAD_PATH = os.path.join(_DOWNLOAD_DIR, 'update.zip')

_lock = threading.Lock()
_thread = None
_cancelled = False
_received = 0
_total = 0
_done = False
_success = False
_error = ''


def download_path():
    return _DOWNLOAD_PATH


def status():
    with _lock:
        return dict(received=_received, total=_total, done=_done,
                     success=_success, error=_error,
                     in_progress=(_thread is not None and _thread.is_alive()))


def start(url, sha256, size, on_progress, on_finished):
    """Begins the download in a background thread. on_progress(received,
    total) and on_finished(success, error) are called from that thread -
    callers needing main-loop affinity (e.g. GLib) must marshal themselves.
    Returns False if a download is already running.
    """
    global _thread, _cancelled, _received, _total, _done, _success, _error
    with _lock:
        if _thread is not None and _thread.is_alive():
            return False
        _cancelled = False
        _received = 0
        _total = size
        _done = False
        _success = False
        _error = ''

    def worker():
        global _received, _total, _done, _success, _error
        os.makedirs(_DOWNLOAD_DIR, exist_ok=True)
        digest = hashlib.sha256()
        try:
            request = urllib.request.Request(
                url, headers={'User-Agent': 'craftparking-update-panel'})
            with urllib.request.urlopen(request, timeout=30) as response:
                content_length = response.getheader('Content-Length')
                if content_length:
                    with _lock:
                        _total = int(content_length)
                with open(_DOWNLOAD_PATH, 'wb') as fp:
                    while True:
                        if _cancelled:
                            raise InterruptedError('cancelled')
                        chunk = response.read(256 * 1024)
                        if not chunk:
                            break
                        fp.write(chunk)
                        digest.update(chunk)
                        with _lock:
                            _received += len(chunk)
                        on_progress(_received, _total)
        except InterruptedError:
            _cleanup_after_failure()
            with _lock:
                _done, _success, _error = True, False, 'cancelled'
            on_finished(False, 'cancelled')
            return
        except Exception as exc:
            log.exception('craftparking download failed')
            _cleanup_after_failure()
            with _lock:
                _done, _success, _error = True, False, str(exc)
            on_finished(False, str(exc))
            return

        actual = digest.hexdigest()
        if actual != sha256.lower():
            _cleanup_after_failure()
            with _lock:
                _done, _success, _error = True, False, 'checksum mismatch'
            on_finished(False, 'checksum mismatch')
            return

        with _lock:
            _done, _success, _error = True, True, ''
        on_finished(True, '')

    _thread = threading.Thread(target=worker, daemon=True)
    _thread.start()
    return True


def _cleanup_after_failure():
    try:
        os.remove(_DOWNLOAD_PATH)
    except OSError:
        pass


def cancel():
    global _cancelled
    with _lock:
        _cancelled = True
