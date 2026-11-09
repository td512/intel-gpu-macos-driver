// SPDX-License-Identifier: MIT
// xe uAPI argument checks (xe_uapi_args.h), function by function after Linux drivers/gpu/drm/xe (MIT, dl/linux-xe):
// xe_bo.c.
#include "xe_uapi_args.h"
#include <sys/errno.h>

// xe_bo.c MAX_USER_EXTENSIONS
static constexpr uint32_t kMaxUserExtensions = 16;

// gem_create_set_pxp_type: NONE is the default; HWDRM needs xe_pxp_key_assign, which is ENODEV with PXP off (xe->pxp
// NULL on every platform without has_pxp)
static int gemCreateSetPxpType(uint64_t value) {
	if (value == DRM_XE_PXP_TYPE_NONE) return 0;
	if (value != DRM_XE_PXP_TYPE_HWDRM) return EINVAL;
	return ENODEV;
}

// gem_create_user_ext_set_property: gem_create_set_property_funcs has the one entry PXP_TYPE (index 0)
static int gemCreateUserExtSetProperty(uint64_t extension, XeUserRead rd, void *ctx) {
	drm_xe_ext_set_property ext;
	if (rd(ctx, extension, &ext, sizeof(ext))) return EFAULT;
	// xe's three tests: below ARRAY_SIZE(gem_create_set_property_funcs), pad 0, and equal to the extension's name
	if (ext.property >= 1 || ext.pad || ext.property != DRM_XE_GEM_CREATE_EXTENSION_SET_PROPERTY) return EINVAL;
	return gemCreateSetPxpType(ext.value);   // gem_create_set_property_funcs[DRM_XE_GEM_CREATE_SET_PROPERTY_PXP_TYPE]
}

// gem_create_user_extensions: recursive in xe (ext_number + 1 per link), a loop here
int xeGemCreateExtensions(uint64_t ext, XeUserRead rd, void *ctx) {
	for (uint32_t n = 0; ext; n++) {
		if (n >= kMaxUserExtensions) return E2BIG;
		drm_xe_user_extension u;
		if (rd(ctx, ext, &u, sizeof(u))) return EFAULT;
		if (u.pad || u.name >= 1) return EINVAL;   // gem_create_user_extension_funcs has one entry, SET_PROPERTY (0)
		if (int err = gemCreateUserExtSetProperty(ext, rd, ctx)) return err;
		ext = u.next_extension;
	}
	return 0;
}
