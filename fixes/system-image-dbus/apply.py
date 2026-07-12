# Copyright (C) 2013-2016 Canonical Ltd.
# Author: Barry Warsaw <barry@ubuntu.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""Reboot issuer."""

__all__ = [
    'BaseApply',
    'Noop',
    'Reboot',
    'factory_reset',
    'production_reset',
    'craftparking_apply_update',
    ]


import os
import shutil
import logging

from subprocess import CalledProcessError, check_call
from systemimage.config import config
from systemimage.helpers import atomic

log = logging.getLogger('systemimage')


class BaseApply:
    """Common apply-the-update actions."""

    def apply(self): # pragma: no cover
        """Subclasses must override this."""
        raise NotImplementedError


class Reboot(BaseApply):
    """Apply the update by rebooting the device."""

    def apply(self):
        try:
            check_call('/sbin/reboot -f recovery'.split(),
                       universal_newlines=True)
        except CalledProcessError as error:
            log.exception('reboot exit status: {}'.format(error.returncode))
            raise
        # This code may or may not run.  We're racing against the system
        # reboot procedure.
        config.dbus_service.Rebooting(True)


class Noop(BaseApply):
    """No-op apply, mostly for testing."""

    def apply(self):
        pass


def factory_reset():
    """Perform a factory reset."""
    command_file = os.path.join(
        config.updater.cache_partition, 'ubuntu_command')
    with atomic(command_file) as fp:
        print('format data', file=fp)
    log.info('Performing a factory reset')
    config.hooks.apply().apply()


def production_reset():
    """Perform a production reset."""
    command_file = os.path.join(
        config.updater.cache_partition, 'ubuntu_command')
    with atomic(command_file) as fp:
        print('format data', file=fp)
        print('enable factory_wipe', file=fp)
    log.info('Performing a production factory reset')
    config.hooks.apply().apply()


# CraftParking: queue a flashable zip for TWRP to install via its own
# OpenRecoveryScript format (`install <path>`), then reboot the same way
# factory_reset()/production_reset() already do above. Deliberately not
# reusing 'ubuntu_command' - that's system-image's own recovery-updater
# format, which this device's TWRP doesn't understand at all.
#
# The unprivileged phablet user can't write to /android/data/media/0 (real
# Android "Internal Storage", root:root-ish, denied even via the sdcard_rw
# group at this raw ext4/f2fs level) - only this root-owned D-Bus service
# can. craftparking_download (also running inside this service) downloads
# straight to /home/phablet/.cache/craftparking-update/update.zip, and this
# function relocates it into the one place TWRP actually looks for install
# media. /home and /android/data are bind mounts of the very same partition
# here (confirmed matching st_dev), so this is a same-filesystem
# os.rename() - instant, not a multi-GB copy - except the shutil.copy2
# fallback below, kept in case that ever isn't true.
#
# Deliberately takes no path argument at all - the only file this ever
# applies is whatever craftparking_download actually downloaded and
# checksum-verified, not an arbitrary caller-supplied path.
# Root's view of the destination (for the actual filesystem operation)
# differs from TWRP's own view of the same file (for the install line)
# purely because of the "/android" bind-mount prefix Halium adds when
# booting Ubuntu Touch - TWRP boots the stock Android environment directly
# and has no notion of that prefix at all.
_UPDATE_DEST_LOCAL = '/android/data/media/0/craftparking-update/update.zip'
_UPDATE_DEST_TWRP = '/data/media/0/craftparking-update/update.zip'


def craftparking_apply_update():
    """Move the downloaded CraftParking zip into place and flash via TWRP."""
    from systemimage import craftparking_download
    src_path = craftparking_download.download_path()
    if not os.path.isfile(src_path):
        log.error('craftparking_apply_update: no downloaded update at {!r}'
                   .format(src_path))
        raise ValueError('no downloaded update available')
    os.makedirs(os.path.dirname(_UPDATE_DEST_LOCAL), exist_ok=True)
    if os.path.exists(_UPDATE_DEST_LOCAL):
        os.remove(_UPDATE_DEST_LOCAL)
    try:
        os.rename(src_path, _UPDATE_DEST_LOCAL)
    except OSError:
        # Cross-device fallback, shouldn't normally trigger - see note above.
        shutil.copy2(src_path, _UPDATE_DEST_LOCAL)
        os.remove(src_path)
    command_file = os.path.join(
        config.updater.cache_partition, 'openrecoveryscript')
    with atomic(command_file) as fp:
        print('install {}'.format(_UPDATE_DEST_TWRP), file=fp)
    log.info('Applying CraftParking update: {}'.format(_UPDATE_DEST_TWRP))
    config.hooks.apply().apply()
