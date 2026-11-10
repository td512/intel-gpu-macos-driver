// SPDX-License-Identifier: MIT
#include <metal_stdlib>
using namespace metal;
struct VIn { float4 pos [[position]]; float3 uvw; };
fragment float4 lod_2d(VIn i [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw.xy), t.calculate_unclamped_lod(s, i.uvw.xy), 0, 1);
}
fragment float4 lod_2da(VIn i [[stage_in]], texture2d_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw.xy), t.calculate_unclamped_lod(s, i.uvw.xy), 0, 1);
}
fragment float4 lod_cube(VIn i [[stage_in]], texturecube<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw), t.calculate_unclamped_lod(s, i.uvw), 0, 1);
}
fragment float4 lod_cubea(VIn i [[stage_in]], texturecube_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw), t.calculate_unclamped_lod(s, i.uvw), 0, 1);
}
fragment float4 lod_3d(VIn i [[stage_in]], texture3d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw), t.calculate_unclamped_lod(s, i.uvw), 0, 1);
}
fragment float4 lod_2d_u(VIn i [[stage_in]], texture2d<uint> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw.xy), t.calculate_unclamped_lod(s, i.uvw.xy), 0, 1);
}
fragment float4 lod_d2d(VIn i [[stage_in]], depth2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw.xy), t.calculate_unclamped_lod(s, i.uvw.xy), 0, 1);
}
fragment float4 lod_d2da(VIn i [[stage_in]], depth2d_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw.xy), t.calculate_unclamped_lod(s, i.uvw.xy), 0, 1);
}
fragment float4 lod_dcube(VIn i [[stage_in]], depthcube<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw), t.calculate_unclamped_lod(s, i.uvw), 0, 1);
}
fragment float4 lod_dcubea(VIn i [[stage_in]], depthcube_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    return float4(t.calculate_clamped_lod(s, i.uvw), t.calculate_unclamped_lod(s, i.uvw), 0, 1);
}
constexpr sampler cs(filter::linear, mip_filter::linear);
fragment float4 lod_cube_const(VIn i [[stage_in]], texturecube<float> t [[texture(0)]]) {
    return float4(t.calculate_clamped_lod(cs, i.uvw), 0, 0, 1);
}
struct PIn {
    float4 pos [[position]];
    interpolant<float4, interpolation::perspective> p4 [[user(a)]];
    interpolant<float2, interpolation::no_perspective> n2 [[user(b)]];
    interpolant<float, interpolation::perspective> p1 [[user(c)]];
    interpolant<half3, interpolation::no_perspective> h3 [[user(d)]];
};
fragment float4 pull_center(PIn i [[stage_in]]) {
    return i.p4.interpolate_at_center() + float4(i.n2.interpolate_at_center(), i.p1.interpolate_at_center(), float(i.h3.interpolate_at_center().x));
}
fragment float4 pull_centroid(PIn i [[stage_in]]) {
    return i.p4.interpolate_at_centroid() + float4(i.n2.interpolate_at_centroid(), i.p1.interpolate_at_centroid(), float(i.h3.interpolate_at_centroid().x));
}
fragment float4 pull_offset(PIn i [[stage_in]], constant float2 &o [[buffer(0)]]) {
    return i.p4.interpolate_at_offset(o) + float4(i.n2.interpolate_at_offset(o), i.p1.interpolate_at_offset(o), float(i.h3.interpolate_at_offset(o).x));
}
fragment float4 pull_sample(PIn i [[stage_in]], uint sid [[sample_id]]) {
    return i.p4.interpolate_at_sample(sid) + float4(i.n2.interpolate_at_sample(sid), i.p1.interpolate_at_sample(sid), float(i.h3.interpolate_at_sample(sid).x));
}
fragment float4 pull_sample_k(PIn i [[stage_in]]) {
    return i.p4.interpolate_at_sample(2);
}
