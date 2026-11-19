// SPDX-License-Identifier: MIT
// Public ABI/link smoke fixture. This is NOT GT4's translated EE or a playable game.
#include "ps2/generated.hpp"
#include "ps2/system.hpp"
#include "ps2/memory.hpp"

#include <cstdint>

namespace {

void synthetic_ee_unit(ps2::Cpu &cpu, std::uint32_t entry, std::uint32_t depth) {
    (void)depth;
    // One synthetic entry, with a deterministic observable register result.
    cpu.r[2].w[0] = entry == 1u ? 0x47543450u : 0u;
    cpu.pc = ps2::kHandlerReturn;
}

constexpr std::uint16_t kEntries[16] = {
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};
static_assert(sizeof(void *) == 8, "Android ARM64 pointer width required");
static_assert(sizeof(ps2::Reg128) == 16, "The PS2 register ABI must remain 128-bit");

} // namespace

// Diagnostic exports. Never pass real game files or execute a PS2 guest image.
extern "C" __attribute__((visibility("default"))) std::uint32_t gt4_public_probe_version() {
    return 9u;
}

extern "C" __attribute__((visibility("default"))) std::uint32_t gt4_public_probe_dispatch() {
    const ps2::UnitInfo unit{0x2000u, 64u, &synthetic_ee_unit, kEntries};
    ps2::register_units(&unit, 1u);
    ps2::Cpu cpu{};
    cpu.pc = 0x2000u;
    ps2::dispatch(cpu, 1u, 0u);
    return cpu.r[2].w[0];
}

extern "C" __attribute__((visibility("default"))) std::uint32_t gt4_public_probe_ram_size() {
    return ps2::kRamSize;
}
