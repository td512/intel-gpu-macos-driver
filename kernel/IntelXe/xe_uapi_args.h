// SPDX-License-Identifier: MIT
// The parts of the xe uAPI that are argument checks and arithmetic only: no device, no locks, no IOKit types, so
// tests/uapi_test.cpp builds them on the host (as xe_platform.cpp). Each function names the Linux function it follows
// (drivers/gpu/drm/xe, dl/linux-xe); xe_core.cpp calls them from the ioctls.
#pragma once
#include <stddef.h>
#include <stdint.h>
#include "uapi/xe_drm.h"

// Reads len bytes of the caller's memory at addr into dst: 0, or EFAULT (copyin in the kext, a fake memory in the test).
typedef int (*XeUserRead)(void *ctx, uint64_t addr, void *dst, size_t len);

// xe_bo.c gem_create_user_extensions -> gem_create_user_ext_set_property -> gem_create_set_pxp_type, on a device without
// PXP (Battlemage: bmg_desc has no has_pxp; xe_pxp_key_assign answers ENODEV). At most MAX_USER_EXTENSIONS (16) in the
// chain (E2BIG), each read once (EFAULT), base.pad 0 and name SET_PROPERTY (EINVAL), the property PXP_TYPE with pad 0
// (EINVAL); PXP_TYPE_NONE accepted, HWDRM ENODEV, any other type EINVAL.
int xeGemCreateExtensions(uint64_t ext, XeUserRead rd, void *ctx);
