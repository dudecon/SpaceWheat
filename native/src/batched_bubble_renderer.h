#ifndef BATCHED_BUBBLE_RENDERER_H
#define BATCHED_BUBBLE_RENDERER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <vector>
#include <cmath>

namespace godot {

/**
 * NativeBubbleRenderer - High-performance batched rendering for quantum bubbles
 *
 * Data layout (density matrix style):
 * Each bubble is a row of 32 float parameters:
 *
 * [0]  x position
 * [1]  y position
 * [2]  base_radius
 * [3]  anim_scale (0-1)
 * [4]  anim_alpha (0-1)
 * [5]  pulse_phase (0-1, from sin() output mapped to 0-1)
 * [6]  is_measured (0 or 1)
 * [7]  is_celestial (0 or 1)
 * [8]  energy (glow intensity, 0-1)
 * [9]  base_color_r
 * [10] base_color_g
 * [11] base_color_b
 * [12] base_color_h (hue for glow tint calculation)
 * [13] base_color_s (saturation)
 * [14] base_color_v (value)
 * [15] individual_purity (0-1)
 * [16] biome_purity (0-1)
 * [17] global_prob (0-1)
 * [18] p_north (probability, 0-1)
 * [19] p_south (probability, 0-1)
 * [20] sink_flux (decoherence rate)
 * [21] time_accumulator (for animations)
 * [22] emoji_north_opacity (0-1)
 * [23] emoji_south_opacity (0-1)
 * [24-31] reserved
 *
 * STRIDE = 32 floats per bubble
 *
 * Usage from GDScript:
 *   var renderer = NativeBubbleRenderer.new()
 *   var data = PackedFloat64Array()  # 24 bubbles * 32 floats = 768 floats
 *   # ... fill data ...
 *   var batches = renderer.generate_draw_batches(data, 24, 32)
 *   # batches["circles"] = [{points, colors}, ...]
 *   # batches["arcs"] = [{points, colors}, ...]
 */
class NativeBubbleRenderer : public RefCounted {
    GDCLASS(NativeBubbleRenderer, RefCounted)

private:
    // Circle segment count for quality
    static const int CIRCLE_SEGMENTS = 24;
    static const int ARC_SEGMENTS = 32;

    // Internal buffers for vertex generation
    std::vector<Vector2> m_circle_points;
    std::vector<Color> m_circle_colors;

    // Precomputed sin/cos tables for circle generation
    std::vector<double> m_sin_table;
    std::vector<double> m_cos_table;

    void _init_trig_tables();

    // Add a filled circle to the batch
    void _add_circle(double cx, double cy, double radius, const Color& color);

    // Add a filled arc (pie slice) to the batch
    void _add_arc(double cx, double cy, double radius,
                  double from_angle, double to_angle,
                  double width, const Color& color);

    // Color utilities
    Color _hsv_to_color(double h, double s, double v, double a) const;
    Color _lighten(const Color& c, double amount) const;

protected:
    static void _bind_methods();

public:
    NativeBubbleRenderer();
    ~NativeBubbleRenderer();

    /**
     * Generate all draw batches from bubble data matrix
     *
     * @param bubble_data PackedFloat64Array[num_bubbles * stride]
     * @param num_bubbles Number of bubbles (rows in the matrix)
     * @param stride Floats per bubble (should be 32)
     * @return Dictionary with:
     *   "points": PackedVector2Array - all triangle vertices
     *   "colors": PackedColorArray - color per vertex
     *   "count": int - number of triangles
     */
    Dictionary generate_draw_batches(const PackedFloat64Array& bubble_data,
                                     int num_bubbles, int stride);

    /**
     * Clear internal buffers (call between frames if reusing)
     */
    void clear_buffers();

    /**
     * Get recommended stride (number of floats per bubble)
     */
    int get_stride() const { return 32; }
};

}

#endif
