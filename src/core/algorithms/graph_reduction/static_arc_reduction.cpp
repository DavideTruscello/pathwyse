#include "static_arc_reduction.h"
#include <limits>
#include <stdlib.h>
#include <algorithm>
#include <random>
#include <cstdint>

StaticArcReduction::StaticArcReduction(Problem* problem) : problem(problem) {
    num_nodes = problem->getNumNodes();

    score.resize(num_nodes, std::vector(num_nodes, std::numeric_limits<double>::max()));
    arcsConnection.resize(num_nodes);

    Resource* obj = problem->getObj();
    max_abs_arc_cost = 1;
    max_abs_node_cost = 1;
    for (int i = 0; i < num_nodes; i++) {
        max_abs_node_cost = std::max(max_abs_node_cost, std::abs(obj->getNodeCost(i)));
        for (auto& j : problem->getNeighbors(i, true))
            max_abs_arc_cost = std::max(max_abs_arc_cost, std::abs(obj->getArcCost(i, j)));
    }
}

double StaticArcReduction::computeScore(int i, int j, double K, double K2) const {
    Resource* obj = problem->getObj();

    const double C_ij = obj->getArcCost(i, j);

    double resource_term = 0.0;
    for (int l = 0; l < problem->getNumRes(); l++) {
        Resource* res = problem->getRes(l);
        const double r_l = res->getArcCost(i, j) + res->getNodeCost(j);
        const double R_l = res->getUB();
        if (R_l != INFPLUS and R_l != 0)
            resource_term += r_l / R_l;
    }
    resource_term = resource_term / problem->getNumRes(); // consumo % media per res
    const double P_s = obj->getNodeCost(i);
    const double P_d = obj->getNodeCost(j);

    // TODO: dividi costi e premi per il costo massimo e premio massimo (in valore assoluto a den)
    return C_ij / max_abs_arc_cost + K * resource_term + K2 * (P_s + P_d) / (max_abs_node_cost*2);
}

void StaticArcReduction::reduce(double beta, double K, double K2) {
    struct ScoredArc { int i, j; double s; };
    std::vector<ScoredArc> arcs;

    for (int i = 0; i < num_nodes; i++) {
        for (auto& j : problem->getNeighbors(i, true)) {
            double s = computeScore(i, j, K, K2);
            score[i][j] = s;
            arcs.push_back({i, j, s});
        }
    }

    std::sort(arcs.begin(), arcs.end(),
              [](const ScoredArc& a, const ScoredArc& b) { return a.s < b.s; });

    size_t n_keep = static_cast<size_t>(beta * arcs.size());

    if(Parameters::isGraphArcsReductionDeterministic()){
        std::cout << "[Graph Arcs Reduction] Using deterministic selection." << std::endl;
        for (size_t idx = 0; idx < n_keep and idx < arcs.size(); idx++) {
            arcsConnection[arcs[idx].i].push_back(arcs[idx].j);
        }
    }
    else{
        std::cout << "[Graph Arcs Reduction] Using hybrid selection with a random component." << std::endl;
        // Selezione ibrida: meta' deterministica (migliori in assoluto),
        // meta' campionata senza reinserimento con pesi esponenziali (Gumbel-top-k).
        const size_t n_total  = std::min(n_keep, arcs.size());
        const size_t n_best   = n_total / 2;           // se dispari, l'arco in piu' va alla parte casuale
        const size_t n_random = n_total - n_best;

        // 1) Parte deterministica: i primi n_best archi (score piu' basso)
        for (size_t idx = 0; idx < n_best; idx++)
            arcsConnection[arcs[idx].i].push_back(arcs[idx].j);

        // 2) Parte casuale: n_random archi estratti dai rimanenti arcs[n_best .. end)
        if (n_random > 0) {
            const double tau   = Parameters::getGraphArcsReductionTemperature();
            const double s_min = arcs[n_best].s;       // arcs e' ordinato: primo e ultimo del pool
            const double s_max = arcs.back().s;
            const double range = s_max - s_min;

            const int seed = Parameters::getGraphArcsReductionSeed();
            std::mt19937_64 rng(seed >= 0 ? static_cast<uint64_t>(seed)
                                        : static_cast<uint64_t>(std::random_device{}()));
            std::uniform_real_distribution<double> unif(std::numeric_limits<double>::min(), 1.0);

            // chiave = log(peso) + rumore di Gumbel; le n_random chiavi piu' alte vengono selezionate
            std::vector<std::pair<double, size_t>> keys;
            keys.reserve(arcs.size() - n_best);
            for (size_t idx = n_best; idx < arcs.size(); idx++) {
                double key;
                if (tau <= 0.0)
                    key = -arcs[idx].s;                                  // tau <= 0: nessun caso, scelta greedy
                else {
                    const double log_w  = (range > 0.0) ? -(arcs[idx].s - s_min) / (tau * range) : 0.0;
                    const double gumbel = -std::log(-std::log(unif(rng)));
                    key = log_w + gumbel;
                }
                keys.emplace_back(key, idx);
            }

            std::nth_element(keys.begin(), keys.begin() + (n_random - 1), keys.end(),
                            [](const std::pair<double, size_t>& a, const std::pair<double, size_t>& b) {
                                return a.first > b.first;
                            });

            for (size_t r = 0; r < n_random; r++) {
                const ScoredArc& a = arcs[keys[r].second];
                arcsConnection[a.i].push_back(a.j);
            }
        }
    }


    ensureDepotConnectivity();
}

void StaticArcReduction::ensureDepotConnectivity() {
    int s = problem->getOrigin();
    int t = problem->getDestination();

    for (auto& j : problem->getNeighbors(s, true)) {
        auto& vec = arcsConnection[s];
        if (std::find(vec.begin(), vec.end(), j) == vec.end())
            vec.push_back(j);
    }

    for (auto& i : problem->getNeighbors(t, false)) {
        auto& vec = arcsConnection[i];
        if (std::find(vec.begin(), vec.end(), t) == vec.end())
            vec.push_back(t);
    }
}

void StaticArcReduction::apply() {
    this->reduce(Parameters::getGraphArcsReductionCutoff(), Parameters::getGraphReductionK1(), Parameters::getGraphReductionK2());
    problem->getNetwork()->clearArcs();
    problem->setNeighbors(arcsConnection);
}
