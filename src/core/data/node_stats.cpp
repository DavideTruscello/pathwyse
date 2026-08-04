
#include "node_stats.h"
#include "algorithms/dynamic_programming/PW_default/LM_default.h"
#include <cmath>
#include <algorithm>

double NodeStats::meanOfObserved(const std::vector<double> & values,
                                 const std::vector<unsigned int> & counts) {
    double sum = 0.0;
    int observed = 0;
    for(size_t v = 0; v < values.size(); v++)
        if(counts[v] > 0) {
            sum += values[v];
            observed++;
        }
    return observed > 0 ? sum / observed : 0.0;
}

void NodeStats::collect(LMDefault* lm, Problem* problem) {
    n_nodes = problem->getNumNodes();
    obj.assign(n_nodes, 0.0);
    res.assign(n_nodes, 0.0);
    count.assign(n_nodes, 0.0);
    n_unobserved = 0;

    std::vector<double> obj_fw = lm->meanObjectPerNode(true);
    std::vector<double> obj_bw = lm->meanObjectPerNode(false);
    std::vector<unsigned int> cnt_fw = lm->labelCountPerNode(true);
    std::vector<unsigned int> cnt_bw = lm->labelCountPerNode(false);

    double neutral_fw = meanOfObserved(obj_fw, cnt_fw);
    double neutral_bw = meanOfObserved(obj_bw, cnt_bw);

    Resource* objective = problem->getObj();

    for(int v = 0; v < n_nodes; v++) {
        double forward  = (cnt_fw[v] > 0) ? obj_fw[v] : neutral_fw;
        double backward = (cnt_bw[v] > 0) ? obj_bw[v] : neutral_bw;
        obj[v] = forward + backward - objective->getNodeCost(v);

        count[v] = static_cast<double>(cnt_fw[v] + cnt_bw[v]);
        if(cnt_fw[v] == 0 and cnt_bw[v] == 0)
            n_unobserved++;
    }

    int counted = 0;
    for(int l = 0; l < problem->getNumRes(); l++) {
        Resource* resource = problem->getRes(l);
        double budget = resource->getUB();
        if(budget == INFPLUS or budget == 0)
            continue;

        std::vector<double> res_fw = lm->meanResConsumption(l, true);
        std::vector<double> res_bw = lm->meanResConsumption(l, false);
        double neutral_res_fw = meanOfObserved(res_fw, cnt_fw);
        double neutral_res_bw = meanOfObserved(res_bw, cnt_bw);

        for(int v = 0; v < n_nodes; v++) {
            double forward  = (cnt_fw[v] > 0) ? res_fw[v] : neutral_res_fw;
            double backward = (cnt_bw[v] > 0) ? res_bw[v] : neutral_res_bw;
            res[v] += (forward + backward - resource->getNodeCost(v)) / budget;
        }
        counted++;
    }

    if(counted > 0)
        for(int v = 0; v < n_nodes; v++)
            res[v] /= counted;

    max_abs_obj = max_abs_res = max_count = 0.0;
    for(int v = 0; v < n_nodes; v++) {
        max_abs_obj = std::max(max_abs_obj, std::fabs(obj[v]));
        max_abs_res = std::max(max_abs_res, std::fabs(res[v]));
        max_count   = std::max(max_count, count[v]);
    }
    if(max_abs_obj < EPS) max_abs_obj = 1.0;
    if(max_abs_res < EPS) max_abs_res = 1.0;
    if(max_count   < EPS) max_count   = 1.0;

    int n_both = 0, n_only_fw = 0, n_only_bw = 0, n_neither = 0;
    for(int v = 0; v < n_nodes; v++) {
        bool f = cnt_fw[v] > 0, b = cnt_bw[v] > 0;
        if(f and b) n_both++;
        else if(f)  n_only_fw++;
        else if(b)  n_only_bw++;
        else        n_neither++;
    }

    available = true;
}

double NodeStats::objectiveTerm(int i, int j) const {
    if(not available) return 0.0;
    return (obj[i] + obj[j]) / (2.0 * max_abs_obj);
}

double NodeStats::resourceTerm(int i, int j) const {
    if(not available) return 0.0;
    return (res[i] + res[j]) / (2.0 * max_abs_res);
}

double NodeStats::labelCountTerm(int i, int j) const {
    if(not available) return 0.0;
    return (count[i] + count[j]) / (2.0 * max_count);
}