/*
 * Copyright 2026 UBports foundation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "vibrator-aw8624.h"

#include <iostream>

namespace hfd {

// Finds the sysfs device backed by the aw8624_haptic kernel driver,
// which exposes "activate" and "duration" attributes directly on its
// own device node.
std::string VibratorAw8624::findDevice() {
    Udev::Udev udev;
    auto enumerate = udev.enumerate_new();
    enumerate.add_match_subsystem("i2c");
    enumerate.scan_devices();

    for (auto &device : enumerate.enumerate_devices()) {
        if (!device.has_driver())
            continue;
        if (device.get_driver() != "aw8624_haptic")
            continue;
        if (device.has_sysattr("activate") && device.has_sysattr("duration"))
            return device.get_syspath();
    }
    return "";
}

bool VibratorAw8624::usable() {
    bool usable = !findDevice().empty();
    std::cout << "VibratorAw8624 usable: " << usable << std::endl;
    return usable;
}

VibratorAw8624::VibratorAw8624(): Vibrator() {
    Udev::Udev udev;
    m_device = udev.device_from_syspath(findDevice());

    // The aw8624 driver defaults to activate_mode=0 (RAM/preset-waveform
    // playback), which plays a fixed-length built-in effect and ignores
    // the "duration" attribute entirely. Mode 1 is duration-based
    // ("cont"-style) playback, where "duration" actually controls how
    // long the motor runs -- this is what we need for arbitrary-length
    // haptic feedback requests from hfd-service.
    if (m_device.has_sysattr("activate_mode")) {
        m_device.set_sysattr("activate_mode", "1");
    }

    // Make sure we are off on init
    configure(State::Off, 0);
}

void VibratorAw8624::configure(State state, int durationMs) {
    if (state == State::On) {
        m_device.set_sysattr("duration", std::to_string(durationMs));
        m_device.set_sysattr("activate", "1");
    } else {
        m_device.set_sysattr("activate", "0");
    }
}
}
