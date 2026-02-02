#ifndef PARAMETRIC_SELECTOR_NATIVE_H
#define PARAMETRIC_SELECTOR_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

namespace godot {

class ParametricSelectorNative : public RefCounted {
	GDCLASS(ParametricSelectorNative, RefCounted);

public:
	enum Metric {
		METRIC_COSINE = 0,
		METRIC_CONNECTION = 1,
		METRIC_LOGARITHMIC = 2,
		METRIC_GAUSSIAN = 3
	};

protected:
	static void _bind_methods();

public:
	ParametricSelectorNative();
	~ParametricSelectorNative();

	// Main API (static methods exposed to GDScript)
	static double compute_similarity(
		const Dictionary &p_vector1,
		const Dictionary &p_vector2,
		int p_metric,
		const Dictionary &p_params
	);

	static Dictionary select_best(
		const Dictionary &p_vector,
		const Array &p_candidates,
		int p_metric,
		const Dictionary &p_params
	);

	static Array select_top_k(
		const Dictionary &p_vector,
		const Array &p_candidates,
		int p_metric,
		int p_k,
		const Dictionary &p_params
	);

	static String select_weighted_random(const Array &p_candidates);
	static Dictionary select_weighted_random_full(const Array &p_candidates);

	// Helpers
	static Dictionary normalize(const Dictionary &p_vector);
	static double magnitude(const Dictionary &p_vector);
	static double dot_product(const Dictionary &p_v1, const Dictionary &p_v2);
	static double logarithmic_weight(double p_amount);
	static double gaussian_match_1d(double p_preference, double p_actual, double p_sigma);

private:
	// Internal implementations
	static double _cosine_similarity(const Dictionary &p_v1, const Dictionary &p_v2);
	static double _connection_similarity(const Dictionary &p_v1, const Dictionary &p_v2, const Dictionary &p_weights);
	static double _logarithmic_total_weight(const Dictionary &p_vector);
	static double _gaussian_similarity(const Dictionary &p_v1, const Dictionary &p_v2, double p_sigma);
};

} // namespace godot

VARIANT_ENUM_CAST(godot::ParametricSelectorNative::Metric);

#endif // PARAMETRIC_SELECTOR_NATIVE_H
