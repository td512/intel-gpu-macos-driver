// SPDX-License-Identifier: MIT
// uapi_test: offline check of the xe uAPI argument checks (xe_uapi_args.cpp) against what Linux xe answers, no GPU needed.
//   1. DRM_XE_GEM_CREATE_EXTENSION_SET_PROPERTY chains (xe_bo.c gem_create_user_extensions on a device without PXP):
//      the error codes, in xe's order, for every field xe looks at, the 16-extension limit and unreadable links
// c++ -std=c++17 -Wall -Wextra -I.. -o uapi_test uapi_test.cpp ../xe_uapi_args.cpp && ./uapi_test
#include <stdio.h>
#include <string.h>
#include <sys/errno.h>
#include "xe_uapi_args.h"

static int fails, checks;
#define CHECK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); \
	printf("\n"); } } while (0)

// A fake user address space: 64 KB at kBase; anything else faults (EFAULT, as copy_from_user).
static constexpr uint64_t kBase = 0x10000000;
static uint8_t gMem[0x10000];
static uint32_t gReads;
static int fakeRead(void *, uint64_t addr, void *dst, size_t len) {
	gReads++;
	if (addr < kBase || addr + len > kBase + sizeof(gMem) || addr + len < addr) return EFAULT;
	memcpy(dst, gMem + (addr - kBase), len);
	return 0;
}
// extension i of a chain at kBase + i * 64
static drm_xe_ext_set_property *ext(uint32_t i) { return reinterpret_cast<drm_xe_ext_set_property *>(gMem + i * 64); }
static uint64_t extAddr(uint32_t i) { return kBase + i * 64; }
static void chain(uint32_t n, uint64_t pxp) {   // n good links, each PXP_TYPE = pxp
	memset(gMem, 0, sizeof(gMem));
	for (uint32_t i = 0; i < n; i++) {
		ext(i)->base.name = DRM_XE_GEM_CREATE_EXTENSION_SET_PROPERTY;
		ext(i)->base.next_extension = i + 1 < n ? extAddr(i + 1) : 0;
		ext(i)->property = DRM_XE_GEM_CREATE_SET_PROPERTY_PXP_TYPE;
		ext(i)->value = pxp;
	}
}
static int run(uint64_t first) { return xeGemCreateExtensions(first, fakeRead, nullptr); }

static void gemCreate() {
	CHECK(run(0) == 0, "no chain");
	chain(1, DRM_XE_PXP_TYPE_NONE);
	CHECK(run(extAddr(0)) == 0, "PXP_TYPE NONE accepted");
	chain(1, DRM_XE_PXP_TYPE_HWDRM);
	CHECK(run(extAddr(0)) == ENODEV, "PXP_TYPE HWDRM: xe_pxp_key_assign without PXP is ENODEV, got %d", run(extAddr(0)));
	chain(1, 2);
	CHECK(run(extAddr(0)) == EINVAL, "an unknown PXP type is EINVAL");
	chain(1, ~0ull);
	CHECK(run(extAddr(0)) == EINVAL, "PXP type ~0 is EINVAL");
	// gem_create_user_extensions: base.pad, then the name
	chain(1, 0);
	ext(0)->base.pad = 1;
	CHECK(run(extAddr(0)) == EINVAL, "base.pad");
	chain(1, 0);
	ext(0)->base.name = 1;
	CHECK(run(extAddr(0)) == EINVAL, "an unknown extension name");
	// gem_create_user_ext_set_property: property in range, pad 0, property == SET_PROPERTY (0)
	chain(1, 0);
	ext(0)->property = 1;
	CHECK(run(extAddr(0)) == EINVAL, "an unknown property");
	chain(1, 0);
	ext(0)->pad = 1;
	CHECK(run(extAddr(0)) == EINVAL, "pad");
	chain(1, 0);
	ext(0)->reserved[0] = ext(0)->reserved[1] = 7;   // xe does not look at reserved here
	CHECK(run(extAddr(0)) == 0, "reserved is not checked by xe");
	// the bad pad wins over a bad value (xe tests the property before calling the setter)
	chain(1, 5);
	ext(0)->pad = 1;
	CHECK(run(extAddr(0)) == EINVAL, "pad before value");
	// MAX_USER_EXTENSIONS = 16: 16 links fine, the 17th E2BIG before it is read
	chain(16, 0);
	CHECK(run(extAddr(0)) == 0, "16 links");
	chain(17, 0);
	gReads = 0;
	CHECK(run(extAddr(0)) == E2BIG, "17 links: E2BIG");
	CHECK(gReads == 32, "17 links: 16 read twice each (base, then the property), the 17th not at all: %u reads", gReads);
	// a loop is caught by the same limit
	chain(2, 0);
	ext(1)->base.next_extension = extAddr(0);
	CHECK(run(extAddr(0)) == E2BIG, "a looping chain ends in E2BIG");
	// faults: the first link, a later link, a link whose property part is outside (the base is readable)
	CHECK(run(0x1000) == EFAULT, "unreadable first link");
	chain(2, 0);
	ext(0)->base.next_extension = 0x2000;
	CHECK(run(extAddr(0)) == EFAULT, "unreadable second link");
	memset(gMem, 0, sizeof(gMem));
	auto *tail = reinterpret_cast<drm_xe_user_extension *>(gMem + sizeof(gMem) - sizeof(drm_xe_user_extension));
	tail->name = DRM_XE_GEM_CREATE_EXTENSION_SET_PROPERTY;
	CHECK(run(kBase + sizeof(gMem) - sizeof(drm_xe_user_extension)) == EFAULT, "base readable, property not: EFAULT");
	// an error in a later link after a good first one; HWDRM in link 2 stops the chain there
	chain(3, 0);
	ext(1)->value = DRM_XE_PXP_TYPE_HWDRM;
	ext(2)->base.pad = 1;
	CHECK(run(extAddr(0)) == ENODEV, "the first failing link decides");
}

int main() {
	gemCreate();
	printf("%d checks, %d failed\n", checks, fails);
	return fails ? 1 : 0;
}
