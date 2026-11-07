#include "superoptimal_pool.h"

#include <iostream>

void SuperoptimalPool::init(int n_nodes) {
    this->n_nodes = n_nodes;
    clear();
}

void SuperoptimalPool::clear() {
    paths.clear();
    seen_tours.clear();
    best_elementary_id = -1;
}

bool SuperoptimalPool::add(const std::vector<int> & tour, int cost, int iteration) {
    //Duplicated tour: nothing to do
    if(not seen_tours.insert(tour).second)
        return false;

    PoolPath p;
    p.tour = tour;
    p.cost = cost;
    p.elementary = isElementary(tour);
    p.iteration = iteration;
    paths.push_back(p);

    //Update best elementary path
    if(p.elementary and (best_elementary_id < 0 or cost < paths[best_elementary_id].cost))
        best_elementary_id = paths.size() - 1;

    return true;
}

int SuperoptimalPool::countElementary() const {
    int count = 0;
    for(auto & p: paths)
        if(p.elementary)
            count++;
    return count;
}

const PoolPath* SuperoptimalPool::getBestElementary() const {
    return best_elementary_id >= 0 ? &paths[best_elementary_id] : nullptr;
}

std::vector<int> SuperoptimalPool::getNodes() const {
    std::vector<bool> in_pool(n_nodes, false);
    std::vector<int> nodes;
    for(auto & p: paths)
        for(int v: p.tour)
            if(not in_pool[v]) {
                in_pool[v] = true;
                nodes.push_back(v);
            }
    return nodes;
}

bool SuperoptimalPool::isElementary(const std::vector<int> & tour) const {
    std::vector<bool> visited(n_nodes, false);
    for(int v: tour) {
        if(visited[v])
            return false;
        visited[v] = true;
    }
    return true;
}

void SuperoptimalPool::print() const {
    std::cout << "--------------------" << std::endl;
    std::cout << "Superoptimal pool: " << size() << " paths, "
              << countElementary() << " elementary, "
              << getNodes().size() << " distinct nodes" << std::endl;

    auto best = getBestElementary();
    if(best) {
        std::cout << "Best elementary path in pool: Obj " << best->cost
                  << " (iteration " << best->iteration << ")" << std::endl;
        std::cout << "Tour: ";
        for(int v: best->tour)
            std::cout << v << " ";
        std::cout << std::endl;
    }
    else
        std::cout << "No elementary path in pool" << std::endl;
}
