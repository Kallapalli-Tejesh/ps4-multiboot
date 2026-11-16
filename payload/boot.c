// Copyright (C) 2026 Chokri Hammedi (blue0x1) <https://github.com/blue0x1>
// linux-2048mb.bin for every PS4: on a PS4 Pro it first switches the GPU to all 4 shader
// engines (kern.neomode_switch=1, what the PS4 system does for Pro-enhanced games), waits for
// the switch, then runs the unchanged Linux loader packed behind this code. On other models
// it runs the loader straight away.
#include "ps4.h"

#define XFAST_SYSCALL_1400 0x1c0
#define DMPML4I_1400 0x1b2c394
#define DMPDPI_1400 0x1b2c398
#define GPU_MMIO_PA 0xe4800000ULL
#define MODE_REG 0x203e
#define MODE_4SE 0x10

// The Linux loader, linked right after this payload (see linker.x).
extern char linux_loader[] __attribute__((visibility("hidden")));

struct info { uint32_t mode, status; };

static inline uint64_t rdmsr_(uint32_t msr) {
  uint32_t lo, hi;
  __asm__ volatile("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
  return ((uint64_t)hi << 32) | lo;
}

// FW 14.00 only: reads the GPU mode register through the kernel's direct map.
static int read_mode(struct thread *td, void *uap) {
  UNUSED(td);
  struct info *in = *(struct info **)((char *)uap + 8);
  uint64_t kbase = rdmsr_(0xC0000082) - XFAST_SYSCALL_1400;
  uint32_t ml4 = *(volatile uint32_t *)(kbase + DMPML4I_1400);
  uint32_t dpi = *(volatile uint32_t *)(kbase + DMPDPI_1400);
  if (ml4 < 256 || ml4 > 511 || dpi > 511) {
    in->status = 2;
    return 0;
  }
  uint64_t dmap = 0xFFFF800000000000ULL | ((uint64_t)ml4 << 39) | ((uint64_t)dpi << 30);
  in->mode = ((volatile uint32_t *)(dmap + GPU_MMIO_PA))[MODE_REG];
  in->status = 1;
  return 0;
}

static uint32_t gpu_mode(void) {
  struct info in = {0, 0};
  kexec(&read_mode, &in);
  return in.status == 1 ? in.mode : 0xffffffff;
}

static void four_engines(void) {
  int neo = 0;
  size_t len = sizeof(neo);
  if (sysctlbyname("kern.neomode", (char *)&neo, &len, NULL, 0) != 0 || neo != 1)
    return;                                   // Not a PS4 Pro.
  int fw14 = get_firmware() == 1400;
  if (fw14 && gpu_mode() == MODE_4SE)
    return;                                   // Already on.
  int v = 1;
  if (sysctlbyname("kern.neomode_switch", NULL, NULL, (char *)&v, sizeof(v)) != 0) {
    printf_notification("4 GPU engines: switch failed (%d). Starting Linux with 2.", *__error());
    return;
  }
  if (fw14) {
    for (int i = 0; i < 40 && gpu_mode() != MODE_4SE; i++)
      sceKernelUsleep(500000);
    if (gpu_mode() != MODE_4SE) {
      printf_notification("4 GPU engines: no switch after 20 s. Starting Linux with 2.");
      return;
    }
  } else {
    sceKernelUsleep(5000000);                 // No register check on this firmware: wait.
  }
  printf_notification("4 GPU engines on. Starting Linux...");
  sceKernelUsleep(1000000);
}

int _main(struct thread *td) {
  initKernel();
  initLibc();
  initSysUtil();
  jailbreak();
  four_engines();
  return ((int (*)(struct thread *))linux_loader)(td);
}
