#include "parametric_selector_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>
#include <limits>
#include <random>

namespace godot {

// Random number generator for weighted random selection
static std::random_device rd;
static std::mt19937 gen(rd());

ParametricSelectorNative::ParametricSelectorNative() {}
ParametricSelectorNative::~ParametricSelectorNative() {}

// ============================================================================
// SIMILARITY METRICS
// ============================================================================

double ParametricSelectorNative::compute_similarity(
	const Dictionary &p_vector1,
	const Dictionary &p_vector2,
	int p_metric,
	const Dictionary &p_params
) {
	switch (p_metric) {
		case METRIC_COSINE:
			return _cosine_similarity(p_vector1, p_vector2);

		case METRIC_CONNECTION: {
			Dictionary connection_weights = p_params.get("connection_weights", Dictionary());
			return _connection_similarity(p_vector1, p_vector2, connection_weights);
		}

		case METRIC_LOGARITHMIC:
			return _logarithmic_total_weight(p_vector1);

		case METRIC_GAUSSIAN: {
			double sigma = p_params.get("sigma", 0.3);
			return _gaussian_similarity(p_vector1, p_vector2, sigma);
		}

		default:
			UtilityFunctions::push_error("ParametricSelectorNative: Unknown metric " + String::num_int64(p_metric));
			return 0.0;
	}
}

// ============================================================================
// INTERNAL: COSINE SIMILARITY
// ============================================================================

double ParametricSelectorNative::_cosine_similarity(const Dictionary &p_v1, const Dictionary &p_v2) {
	if (p_v1.is_empty() || p_v2.is_empty()) {
		return 0.0;
	}

	// Compute ||v1||²
	double norm1_sq = 0.0;
	Array keys1 = p_v1.keys();
	for (int i = 0; i < keys1.size(); i++) {
		Variant key = keys1[i];
		double val = p_v1[key];
		norm1_sq += val * val;
	}

	if (norm1_sq < 1e-9) {
		return 0.0;
	}

	// Compute ||v2||²
	double norm2_sq = 0.0;
	Array keys2 = p_v2.keys();
	for (int i = 0; i < keys2.size(); i++) {
		Variant key = keys2[i];
		double val = p_v2[key];
		norm2_sq += val * val;
	}

	if (norm2_sq < 1e-9) {
		return 0.0;
	}

	// Compute v1 · v2
	double dot = 0.0;
	for (int i = 0; i < keys1.size(); i++) {
		Variant key = keys1[i];
		if (p_v2.has(key)) {
			double v1_val = p_v1[key];
			double v2_val = p_v2[key];
			dot += v1_val * v2_val;
		}
	}

	// cos²(v1, v2)
	double norm1 = std::sqrt(norm1_sq);
	double norm2 = std::sqrt(norm2_sq);
	double cos_theta = dot / (norm1 * norm2);
	return cos_theta * cos_theta;
}

// ============================================================================
// INTERNAL: CONNECTION STRENGTH
// ============================================================================

double ParametricSelectorNative::_connection_similarity(
	const Dictionary &p_v1,
	const Dictionary &p_v2,
	const Dictionary &p_weights
) {
	if (p_v1.is_empty() || p_v2.is_empty()) {
		return 0.0;
	}

	double total_weight = 0.0;
	int connection_count = 0;

	Array keys1 = p_v1.keys();
	for (int i = 0; i < keys1.size(); i++) {
		Variant emoji1 = keys1[i];

		if (!p_weights.has(emoji1)) {
			continue;
		}

		Variant connections_var = p_weights[emoji1];
		if (connections_var.get_type() != Variant::DICTIONARY) {
			continue;
		}

		Dictionary connections = connections_var;
		if (connections.is_empty()) {
			continue;
		}

		Array keys2 = p_v2.keys();
		for (int j = 0; j < keys2.size(); j++) {
			Variant emoji2 = keys2[j];

			if (!connections.has(emoji2)) {
				continue;
			}

			Variant conn_data = connections[emoji2];
			double weight = 0.0;

			if (conn_data.get_type() == Variant::DICTIONARY) {
				Dictionary conn_dict = conn_data;
				weight = conn_dict.get("weight", 0.0);
			} else {
				weight = conn_data;
			}

			total_weight += weight;
			connection_count++;
		}
	}

	return connection_count > 0 ? total_weight / static_cast<double>(connection_count) : 0.0;
}

// ============================================================================
// INTERNAL: LOGARITHMIC WEIGHT
// ============================================================================

double ParametricSelectorNative::_logarithmic_total_weight(const Dictionary &p_vector) {
	double total_weight = 0.0;

	Array keys = p_vector.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key = keys[i];
		double amount = p_vector[key];

		if (amount > 0.0) {
			total_weight += 1.0 + std::log(1.0 + amount) / 3.0;
		}
	}

	return total_weight;
}

double ParametricSelectorNative::logarithmic_weight(double p_amount) {
	if (p_amount <= 0.0) {
		return 1.0;
	}
	return 1.0 + std::log(1.0 + p_amount) / 3.0;
}

// ============================================================================
// INTERNAL: GAUSSIAN SIMILARITY
// ============================================================================

double ParametricSelectorNative::_gaussian_similarity(
	const Dictionary &p_v1,
	const Dictionary &p_v2,
	double p_sigma
) {
	if (p_v1.is_empty() || p_v2.is_empty()) {
		return 0.0;
	}

	// Collect all keys
	Dictionary all_keys;
	Array keys1 = p_v1.keys();
	for (int i = 0; i < keys1.size(); i++) {
		all_keys[keys1[i]] = true;
	}
	Array keys2 = p_v2.keys();
	for (int i = 0; i < keys2.size(); i++) {
		all_keys[keys2[i]] = true;
	}

	// Compute squared Euclidean distance
	double dist_sq = 0.0;
	Array all_keys_array = all_keys.keys();
	for (int i = 0; i < all_keys_array.size(); i++) {
		Variant key = all_keys_array[i];
		double v1 = p_v1.get(key, 0.0);
		double v2 = p_v2.get(key, 0.0);
		double diff = v1 - v2;
		dist_sq += diff * diff;
	}

	return std::exp(-dist_sq / (2.0 * p_sigma * p_sigma));
}

double ParametricSelectorNative::gaussian_match_1d(double p_preference, double p_actual, double p_sigma) {
	double diff = p_preference - p_actual;
	return std::exp(-(diff * diff) / (2.0 * p_sigma * p_sigma));
}

// ============================================================================
// SELECTION METHODS
// ============================================================================

Dictionary ParametricSelectorNative::select_best(
	const Dictionary &p_vector,
	const Array &p_candidates,
	int p_metric,
	const Dictionary &p_params
) {
	if (p_candidates.is_empty()) {
		return Dictionary();
	}

	Dictionary best_candidate;
	double best_similarity = -std::numeric_limits<double>::infinity();

	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		Dictionary candidate_vector = candidate.get("vector", Dictionary());

		double similarity = compute_similarity(p_vector, candidate_vector, p_metric, p_params);

		if (similarity > best_similarity) {
			best_similarity = similarity;
			best_candidate = candidate.duplicate();
		}
	}

	if (!best_candidate.is_empty()) {
		best_candidate["similarity"] = best_similarity;
	}

	return best_candidate;
}

Array ParametricSelectorNative::select_top_k(
	const Dictionary &p_vector,
	const Array &p_candidates,
	int p_metric,
	int p_k,
	const Dictionary &p_params
) {
	Array results;

	if (p_candidates.is_empty()) {
		return results;
	}

	// Compute similarity for all candidates
	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		Dictionary candidate_vector = candidate.get("vector", Dictionary());

		double similarity = compute_similarity(p_vector, candidate_vector, p_metric, p_params);

		Dictionary result = candidate.duplicate();
		result["similarity"] = similarity;
		results.append(result);
	}

	// Sort by similarity (descending) - bubble sort for simplicity
	for (int i = 0; i < results.size() - 1; i++) {
		for (int j = 0; j < results.size() - i - 1; j++) {
			Dictionary a = results[j];
			Dictionary b = results[j + 1];
			double sim_a = a.get("similarity", 0.0);
			double sim_b = b.get("similarity", 0.0);

			if (sim_a < sim_b) {
				results[j] = b;
				results[j + 1] = a;
			}
		}
	}

	// Return top K
	if (p_k > 0 && p_k < results.size()) {
		return results.slice(0, p_k);
	}

	return results;
}

String ParametricSelectorNative::select_weighted_random(const Array &p_candidates) {
	if (p_candidates.is_empty()) {
		return String();
	}

	double total_weight = 0.0;
	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		total_weight += static_cast<double>(candidate.get("weight", 0.0));
	}

	if (total_weight < 1e-9) {
		return String();
	}

	std::uniform_real_distribution<> dis(0.0, total_weight);
	double roll = dis(gen);
	double cumulative = 0.0;

	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		cumulative += static_cast<double>(candidate.get("weight", 0.0));

		if (roll <= cumulative) {
			return candidate.get("name", String());
		}
	}

	Dictionary last = p_candidates[p_candidates.size() - 1];
	return last.get("name", String());
}

Dictionary ParametricSelectorNative::select_weighted_random_full(const Array &p_candidates) {
	if (p_candidates.is_empty()) {
		return Dictionary();
	}

	double total_weight = 0.0;
	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		total_weight += static_cast<double>(candidate.get("weight", 0.0));
	}

	if (total_weight < 1e-9) {
		return Dictionary();
	}

	std::uniform_real_distribution<> dis(0.0, total_weight);
	double roll = dis(gen);
	double cumulative = 0.0;

	for (int i = 0; i < p_candidates.size(); i++) {
		Dictionary candidate = p_candidates[i];
		cumulative += static_cast<double>(candidate.get("weight", 0.0));

		if (roll <= cumulative) {
			return candidate.duplicate();
		}
	}

	Dictionary last = p_candidates[p_candidates.size() - 1];
	return last.duplicate();
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

Dictionary ParametricSelectorNative::normalize(const Dictionary &p_vector) {
	if (p_vector.is_empty()) {
		return Dictionary();
	}

	double norm_sq = 0.0;
	Array keys = p_vector.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key = keys[i];
		double val = p_vector[key];
		norm_sq += val * val;
	}

	double norm = std::sqrt(norm_sq);
	if (norm < 1e-9) {
		return Dictionary();
	}

	Dictionary normalized;
	for (int i = 0; i < keys.size(); i++) {
		Variant key = keys[i];
		double val = p_vector[key];
		normalized[key] = val / norm;
	}

	return normalized;
}

double ParametricSelectorNative::magnitude(const Dictionary &p_vector) {
	if (p_vector.is_empty()) {
		return 0.0;
	}

	double sum_sq = 0.0;
	Array keys = p_vector.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key = keys[i];
		double val = p_vector[key];
		sum_sq += val * val;
	}

	return std::sqrt(sum_sq);
}

double ParametricSelectorNative::dot_product(const Dictionary &p_v1, const Dictionary &p_v2) {
	if (p_v1.is_empty() || p_v2.is_empty()) {
		return 0.0;
	}

	double dot = 0.0;
	Array keys1 = p_v1.keys();
	for (int i = 0; i < keys1.size(); i++) {
		Variant key = keys1[i];
		if (p_v2.has(key)) {
			double v1_val = p_v1[key];
			double v2_val = p_v2[key];
			dot += v1_val * v2_val;
		}
	}

	return dot;
}

// ============================================================================
// GODOT BINDINGS
// ============================================================================

void ParametricSelectorNative::_bind_methods() {
	// Metric enum
	BIND_ENUM_CONSTANT(METRIC_COSINE);
	BIND_ENUM_CONSTANT(METRIC_CONNECTION);
	BIND_ENUM_CONSTANT(METRIC_LOGARITHMIC);
	BIND_ENUM_CONSTANT(METRIC_GAUSSIAN);

	// Main API
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("compute_similarity", "vector1", "vector2", "metric", "params"), &ParametricSelectorNative::compute_similarity);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("select_best", "vector", "candidates", "metric", "params"), &ParametricSelectorNative::select_best);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("select_top_k", "vector", "candidates", "metric", "k", "params"), &ParametricSelectorNative::select_top_k);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("select_weighted_random", "candidates"), &ParametricSelectorNative::select_weighted_random);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("select_weighted_random_full", "candidates"), &ParametricSelectorNative::select_weighted_random_full);

	// Helpers
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("normalize", "vector"), &ParametricSelectorNative::normalize);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("magnitude", "vector"), &ParametricSelectorNative::magnitude);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("dot_product", "v1", "v2"), &ParametricSelectorNative::dot_product);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("logarithmic_weight", "amount"), &ParametricSelectorNative::logarithmic_weight);
	ClassDB::bind_static_method("ParametricSelectorNative", D_METHOD("gaussian_match_1d", "preference", "actual", "sigma"), &ParametricSelectorNative::gaussian_match_1d);
}

} // namespace godot
