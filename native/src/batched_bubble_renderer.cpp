#include "batched_bubble_renderer.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

using namespace godot;

// Parameter indices (density matrix columns)
namespace BubbleParam {
    const int X = 0;
    const int Y = 1;
    const int BASE_RADIUS = 2;
    const int ANIM_SCALE = 3;
    const int ANIM_ALPHA = 4;
    const int PULSE_PHASE = 5;  // Already mapped 0-1
    const int IS_MEASURED = 6;
    const int IS_CELESTIAL = 7;
    const int ENERGY = 8;
    const int COLOR_R = 9;
    const int COLOR_G = 10;
    const int COLOR_B = 11;
    const int COLOR_H = 12;
    const int COLOR_S = 13;
    const int COLOR_V = 14;
    const int INDIVIDUAL_PURITY = 15;
    const int BIOME_PURITY = 16;
    const int GLOBAL_PROB = 17;
    const int P_NORTH = 18;
    const int P_SOUTH = 19;
    const int SINK_FLUX = 20;
    const int TIME = 21;
    const int EMOJI_NORTH_OPACITY = 22;
    const int EMOJI_SOUTH_OPACITY = 23;
}

void NativeBubbleRenderer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("generate_draw_batches", "bubble_data", "num_bubbles", "stride"),
                         &NativeBubbleRenderer::generate_draw_batches);
    ClassDB::bind_method(D_METHOD("clear_buffers"), &NativeBubbleRenderer::clear_buffers);
    ClassDB::bind_method(D_METHOD("get_stride"), &NativeBubbleRenderer::get_stride);
}

NativeBubbleRenderer::NativeBubbleRenderer() {
    _init_trig_tables();
    // Reserve space for typical use case (24 bubbles, ~12 circles each, 3 verts/tri, ~24 tris/circle)
    m_circle_points.reserve(24 * 12 * 24 * 3);
    m_circle_colors.reserve(24 * 12 * 24 * 3);
}

NativeBubbleRenderer::~NativeBubbleRenderer() {}

void NativeBubbleRenderer::_init_trig_tables() {
    // Precompute sin/cos for maximum segment count
    int max_segments = std::max(CIRCLE_SEGMENTS, ARC_SEGMENTS) + 1;
    m_sin_table.resize(max_segments);
    m_cos_table.resize(max_segments);

    for (int i = 0; i < max_segments; i++) {
        double angle = (2.0 * M_PI * i) / (max_segments - 1);
        m_sin_table[i] = std::sin(angle);
        m_cos_table[i] = std::cos(angle);
    }
}

Color NativeBubbleRenderer::_hsv_to_color(double h, double s, double v, double a) const {
    // HSV to RGB conversion
    double c = v * s;
    double x = c * (1.0 - std::abs(std::fmod(h * 6.0, 2.0) - 1.0));
    double m = v - c;

    double r, g, b;
    int sector = static_cast<int>(h * 6.0) % 6;

    switch (sector) {
        case 0: r = c; g = x; b = 0; break;
        case 1: r = x; g = c; b = 0; break;
        case 2: r = 0; g = c; b = x; break;
        case 3: r = 0; g = x; b = c; break;
        case 4: r = x; g = 0; b = c; break;
        default: r = c; g = 0; b = x; break;
    }

    return Color(r + m, g + m, b + m, a);
}

Color NativeBubbleRenderer::_lighten(const Color& c, double amount) const {
    return Color(
        std::min(1.0, c.r + (1.0 - c.r) * amount),
        std::min(1.0, c.g + (1.0 - c.g) * amount),
        std::min(1.0, c.b + (1.0 - c.b) * amount),
        c.a
    );
}

void NativeBubbleRenderer::_add_circle(double cx, double cy, double radius, const Color& color) {
    if (radius < 0.5) return;  // Skip tiny circles
    if (color.a < 0.02) return;  // Skip nearly invisible geometry

    Vector2 center(cx, cy);

    // Fan triangulation from center
    for (int i = 0; i < CIRCLE_SEGMENTS; i++) {
        int next = (i + 1) % CIRCLE_SEGMENTS;

        double angle1 = (2.0 * M_PI * i) / CIRCLE_SEGMENTS;
        double angle2 = (2.0 * M_PI * next) / CIRCLE_SEGMENTS;

        Vector2 p1(cx + radius * std::cos(angle1), cy + radius * std::sin(angle1));
        Vector2 p2(cx + radius * std::cos(angle2), cy + radius * std::sin(angle2));

        // Triangle: center, p1, p2
        m_circle_points.push_back(center);
        m_circle_points.push_back(p1);
        m_circle_points.push_back(p2);

        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);
    }
}

void NativeBubbleRenderer::_add_arc(double cx, double cy, double radius,
                                      double from_angle, double to_angle,
                                      double width, const Color& color) {
    if (radius < 0.5 || width < 0.5) return;
    if (color.a < 0.02) return;  // Skip nearly invisible geometry

    double inner_radius = radius - width * 0.5;
    double outer_radius = radius + width * 0.5;
    if (inner_radius < 0) inner_radius = 0;

    double angle_span = to_angle - from_angle;
    if (std::abs(angle_span) < 0.01) return;

    int segments = std::max(8, static_cast<int>(std::abs(angle_span) * ARC_SEGMENTS / (2.0 * M_PI)));

    for (int i = 0; i < segments; i++) {
        double t1 = static_cast<double>(i) / segments;
        double t2 = static_cast<double>(i + 1) / segments;

        double a1 = from_angle + angle_span * t1;
        double a2 = from_angle + angle_span * t2;

        double cos1 = std::cos(a1);
        double sin1 = std::sin(a1);
        double cos2 = std::cos(a2);
        double sin2 = std::sin(a2);

        Vector2 inner1(cx + inner_radius * cos1, cy + inner_radius * sin1);
        Vector2 outer1(cx + outer_radius * cos1, cy + outer_radius * sin1);
        Vector2 inner2(cx + inner_radius * cos2, cy + inner_radius * sin2);
        Vector2 outer2(cx + outer_radius * cos2, cy + outer_radius * sin2);

        // Two triangles for the quad
        m_circle_points.push_back(inner1);
        m_circle_points.push_back(outer1);
        m_circle_points.push_back(inner2);
        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);

        m_circle_points.push_back(inner2);
        m_circle_points.push_back(outer1);
        m_circle_points.push_back(outer2);
        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);
        m_circle_colors.push_back(color);
    }
}

void NativeBubbleRenderer::clear_buffers() {
    m_circle_points.clear();
    m_circle_colors.clear();
}

Dictionary NativeBubbleRenderer::generate_draw_batches(const PackedFloat64Array& bubble_data,
                                                         int num_bubbles, int stride) {
    clear_buffers();

    const double* data = bubble_data.ptr();
    int data_size = bubble_data.size();

    for (int b = 0; b < num_bubbles; b++) {
        int offset = b * stride;
        if (offset + stride > data_size) break;

        const double* bp = data + offset;  // Bubble parameters

        double x = bp[BubbleParam::X];
        double y = bp[BubbleParam::Y];
        double base_radius = bp[BubbleParam::BASE_RADIUS];
        double anim_scale = bp[BubbleParam::ANIM_SCALE];
        double anim_alpha = bp[BubbleParam::ANIM_ALPHA];
        double pulse_phase = bp[BubbleParam::PULSE_PHASE];
        bool is_measured = bp[BubbleParam::IS_MEASURED] > 0.5;
        bool is_celestial = bp[BubbleParam::IS_CELESTIAL] > 0.5;
        double energy = bp[BubbleParam::ENERGY];
        double color_r = bp[BubbleParam::COLOR_R];
        double color_g = bp[BubbleParam::COLOR_G];
        double color_b = bp[BubbleParam::COLOR_B];
        double color_h = bp[BubbleParam::COLOR_H];
        double color_s = bp[BubbleParam::COLOR_S];
        double color_v = bp[BubbleParam::COLOR_V];
        double individual_purity = bp[BubbleParam::INDIVIDUAL_PURITY];
        double biome_purity = bp[BubbleParam::BIOME_PURITY];
        double global_prob = bp[BubbleParam::GLOBAL_PROB];
        double p_north = bp[BubbleParam::P_NORTH];
        double p_south = bp[BubbleParam::P_SOUTH];
        double sink_flux = bp[BubbleParam::SINK_FLUX];
        double time = bp[BubbleParam::TIME];

        if (anim_scale <= 0.0) continue;

        // Calculate effective radius with pulse
        double pulse_scale = 1.0 + pulse_phase * 0.08;
        double effective_radius = base_radius * anim_scale * pulse_scale;

        Color base_color(color_r, color_g, color_b, 1.0);

        // Glow tint (complementary hue)
        double glow_h = std::fmod(color_h + 0.5, 1.0);
        double glow_s = std::min(color_s * 1.3, 1.0);
        double glow_v = std::max(color_v * 0.6, 0.3);
        Color glow_tint = _hsv_to_color(glow_h, glow_s, glow_v, 1.0);

        double glow_alpha = (energy * 0.5 + 0.3) * anim_alpha;

        // === LAYER 1-2: OUTER GLOWS ===
        if (is_measured && !is_celestial) {
            // Measured glow - cyan pulsing
            double measured_pulse = 0.5 + 0.5 * std::sin(time * 4.0);

            Color outer_ring(0.0, 1.0, 1.0, (0.4 + 0.3 * measured_pulse) * anim_alpha);
            _add_circle(x, y, base_radius * (2.2 + 0.3 * measured_pulse) * anim_scale, outer_ring);

            Color measured_glow(0.2, 0.95, 1.0, 0.8 * anim_alpha);
            _add_circle(x, y, base_radius * 1.6 * anim_scale, measured_glow);

            Color inner_glow(0.8, 1.0, 1.0, 0.95 * anim_alpha);
            _add_circle(x, y, base_radius * 1.3 * anim_scale, inner_glow);
        } else {
            // Unmeasured glow - complementary tint
            double outer_mult = is_celestial ? 2.2 : 1.6;
            Color outer_glow = glow_tint;
            outer_glow.a = glow_alpha * 0.4;
            _add_circle(x, y, effective_radius * outer_mult, outer_glow);

            double mid_mult = is_celestial ? 1.8 : 1.3;
            Color mid_glow = glow_tint;
            mid_glow.a = glow_alpha * 0.6;
            _add_circle(x, y, effective_radius * mid_mult, mid_glow);

            if (is_celestial && glow_alpha > 0) {
                Color inner_glow = _lighten(glow_tint, 0.2);
                inner_glow.a = glow_alpha * 0.8;
                _add_circle(x, y, effective_radius * 1.4, inner_glow);
            }
        }

        // === LAYER 3: Dark background ===
        Color dark_bg(0.1, 0.1, 0.15, 0.85);
        double bg_mult = is_celestial ? 1.12 : 1.08;
        _add_circle(x, y, effective_radius * bg_mult, dark_bg);

        // === LAYER 4: Main bubble ===
        Color main_color = _lighten(base_color, is_celestial ? 0.1 : 0.15);
        main_color.a = 0.75 * anim_alpha;
        _add_circle(x, y, effective_radius, main_color);

        // === LAYER 5: Glossy center ===
        Color bright_center = _lighten(base_color, 0.6);
        bright_center.a = 0.8 * anim_alpha;
        double spot_size = is_celestial ? 0.4 : 0.5;
        _add_circle(x - effective_radius * 0.25, y - effective_radius * 0.25,
                    effective_radius * spot_size, bright_center);

        // === LAYER 6: Outline ===
        if (is_measured && !is_celestial) {
            double measured_pulse = 0.5 + 0.5 * std::sin(time * 4.0);

            Color measured_outline(0.0, 1.0, 1.0, (0.85 + 0.15 * measured_pulse) * anim_alpha);
            _add_arc(x, y, base_radius * 1.08 * anim_scale, 0, 2.0 * M_PI, 5.0, measured_outline);

            Color inner_outline(1.0, 1.0, 1.0, 0.95 * anim_alpha);
            _add_arc(x, y, base_radius * 1.0 * anim_scale, 0, 2.0 * M_PI, 3.0, inner_outline);

            // Checkmark indicator
            Color check_color(0.2, 1.0, 0.4, 0.95 * anim_alpha);
            _add_circle(x + base_radius * 0.7 * anim_scale, y - base_radius * 0.7 * anim_scale,
                        6.0 * anim_scale, check_color);
        } else {
            Color outline_color = is_celestial ? Color(1.0, 0.9, 0.3, 0.95 * anim_alpha)
                                               : Color(1.0, 1.0, 1.0, 0.95 * anim_alpha);
            double outline_width = is_celestial ? 3.0 : 2.5;
            _add_arc(x, y, effective_radius * 1.02, 0, 2.0 * M_PI, outline_width, outline_color);
        }

        // === LAYER 6b: Purity ring (inner) ===
        if (!is_celestial && individual_purity > 0.01) {
            Color purity_color;
            if (individual_purity > biome_purity + 0.05) {
                purity_color = Color(0.4, 0.9, 1.0, 0.6 * anim_alpha);  // Cyan: purer
            } else if (individual_purity < biome_purity - 0.05) {
                purity_color = Color(1.0, 0.4, 0.8, 0.6 * anim_alpha);  // Magenta: mixed
            } else {
                purity_color = Color(0.9, 0.9, 0.9, 0.4 * anim_alpha);  // White: average
            }

            double purity_radius = effective_radius * 0.6;
            double purity_extent = individual_purity * 2.0 * M_PI;
            _add_arc(x, y, purity_radius, -M_PI / 2, -M_PI / 2 + purity_extent, 2.0, purity_color);
        }

        // === LAYER 6c: Probability ring (outer) ===
        if (!is_celestial && global_prob > 0.01) {
            Color arc_color(1.0, 1.0, 1.0, 0.4 * anim_alpha);
            double arc_radius = effective_radius * 1.25;
            double arc_extent = global_prob * 2.0 * M_PI;
            _add_arc(x, y, arc_radius, -M_PI / 2, -M_PI / 2 + arc_extent, 2.0, arc_color);
        }

        // === LAYER 6d: Measurement uncertainty ring ===
        if (!is_celestial) {
            double mass = p_north + p_south;
            if (mass > 0.001) {
                double p_n = p_north / mass;
                double p_s = p_south / mass;
                double uncertainty = 2.0 * std::sqrt(p_n * p_s);

                if (uncertainty > 0.05) {
                    double ring_radius = effective_radius * 1.15;
                    double max_thickness = 6.0;
                    double thickness = max_thickness * uncertainty;

                    // Blue to magenta gradient based on uncertainty
                    double hue = 0.75 - uncertainty * 0.15;
                    Color ring_color = _hsv_to_color(hue, 0.7, 0.9, 0.6 * anim_alpha * uncertainty);
                    _add_arc(x, y, ring_radius, 0, 2.0 * M_PI, thickness, ring_color);

                    // Inner glow at high uncertainty
                    if (uncertainty > 0.7) {
                        Color glow_color = ring_color;
                        glow_color.a = 0.3 * anim_alpha;
                        _add_arc(x, y, ring_radius, 0, 2.0 * M_PI, thickness * 2.0, glow_color);
                    }
                }
            }
        }

        // === LAYER 6e: Sink flux particles ===
        if (!is_celestial && sink_flux > 0.001) {
            int particle_count = static_cast<int>(std::min(std::max(sink_flux * 20.0, 1.0), 6.0));
            for (int i = 0; i < particle_count; i++) {
                double particle_time = time * 0.5 + static_cast<double>(i) * 0.3;
                double particle_phase = std::fmod(particle_time, 1.0);

                double angle = (static_cast<double>(i) / particle_count) * 2.0 * M_PI + particle_time * 2.0;
                double dist = effective_radius * (1.2 + particle_phase * 0.8);

                double px = x + std::cos(angle) * dist;
                double py = y + std::sin(angle) * dist;
                double particle_alpha = (1.0 - particle_phase) * 0.6 * anim_alpha;
                Color particle_color(0.8, 0.4, 0.2, particle_alpha);
                double particle_size = 3.0 * (1.0 - particle_phase * 0.5);

                _add_circle(px, py, particle_size, particle_color);
            }
        }
    }

    // Convert to Godot packed arrays
    PackedVector2Array points;
    PackedColorArray colors;
    PackedInt32Array indices;

    points.resize(m_circle_points.size());
    colors.resize(m_circle_colors.size());
    indices.resize(m_circle_points.size());

    Vector2* points_ptr = points.ptrw();
    Color* colors_ptr = colors.ptrw();
    int32_t* indices_ptr = indices.ptrw();

    for (size_t i = 0; i < m_circle_points.size(); i++) {
        points_ptr[i] = m_circle_points[i];
        colors_ptr[i] = m_circle_colors[i];
        indices_ptr[i] = static_cast<int32_t>(i);  // Sequential indices for triangles
    }

    Dictionary result;
    result["points"] = points;
    result["colors"] = colors;
    result["indices"] = indices;
    result["triangle_count"] = static_cast<int>(m_circle_points.size() / 3);

    return result;
}
