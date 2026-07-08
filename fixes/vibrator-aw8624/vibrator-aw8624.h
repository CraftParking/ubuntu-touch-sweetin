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

#pragma once

#include "vibrator.h"
#include "udev/udev-cpp.h"

namespace hfd {
// Some devices (e.g. certain Qualcomm SM7150-era Xiaomi phones) use an
// Awinic AW8624 (or similar) haptic driver IC that registers a Force
// Feedback capable input device, but whose kernel FF_RUMBLE upload
// (EVIOCSFF) implementation is non-functional -- VibratorFF's usable()
// check only tests the capability bitmask, not whether upload actually
// succeeds, so devices in this state silently get no haptics at all
// even though the driver exposes a working activate/duration sysfs
// interface directly on its own device node (not under
// /sys/class/leds/vibrator, which VibratorSysfs expects).
class VibratorAw8624 : public Vibrator {

public:
    VibratorAw8624();

    static bool usable();
    static std::string findDevice();
protected:
    void configure(State state, int durationMs) override;

private:
    Udev::UdevDevice m_device;
};
}
