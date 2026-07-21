#ifndef RESOURCE_DATA_H
#define RESOURCE_DATA_H

#include <vector>
#include <map>
#include <math.h>

struct ResourceData {

    /** Resource data management **/
    //Constructors and Destructors
    explicit ResourceData(int n_nodes) {this->n_nodes = n_nodes;}
    virtual ~ResourceData() = default;

    virtual void reset() {node_costs.clear();};

    /** Node Data **/
    void setNodeCosts(std::vector<int> node_costs){this->node_costs = node_costs;}
    void setNodeCost(int id, int cost){
        if(node_costs.empty())
            node_costs.resize(n_nodes, 0);
        node_costs[id] = cost;
        if (max_node_cost_abs < abs(cost))
            max_node_cost_abs = abs(cost);
    }

    void increaseNodeCost(int id, int delta) {
        if(not node_costs.empty())
            node_costs[id] += delta;
    }

    void multiplyNodeCost(int id, float factor) {
        if(not node_costs.empty())
            node_costs[id] *= factor;
    }

    int getNodeCost(int id){return node_costs.empty() ? 0: node_costs[id];}
    std::vector<int> & getNodeCost() {return node_costs;}

    int getMaxAbsNodeCost() const {
        return max_node_cost_abs;
    }

    int getMaxAbsArcCost() const { return max_arc_cost_abs; }

    /** Arc Data **/
    virtual void setArcCost(int i, int j, int cost) = 0;
    virtual void increaseArcCost(int i, int j, int delta) = 0;
    virtual void multiplyArcCost(int i, int j, float factor) = 0;
    virtual int getArcCost(int i, int j) = 0;

    /** Scaling **/
    virtual void scaleData(float scaling) = 0;

protected:
    int n_nodes;
    std::vector<int> node_costs;
    int max_node_cost_abs = std::numeric_limits<int>::min();
    int max_arc_cost_abs = std::numeric_limits<int>::min();
};

struct ResourceDataMap: ResourceData {

    /** Resource data management **/
    //Constructors and Destructors
    explicit ResourceDataMap(int n_nodes): ResourceData(n_nodes) {
        arc_costs.resize(n_nodes, std::map<int, int>());
    }
    ~ResourceDataMap() = default;

    void reset() override {ResourceData::reset(); arc_costs.clear();}

    /** Arc Data **/
    void setArcCost(int i, int j, int cost) override {
        auto position = arc_costs[i].find(j);
        if(position == arc_costs[i].end())
            arc_costs[i].insert(std::make_pair(j, cost));
        else
            position->second = cost;

        if (abs(cost) > this->max_arc_cost_abs)
            this->max_arc_cost_abs = abs(cost);
    }

    void increaseArcCost(int i, int j, int delta) override {
        auto position = arc_costs[i].find(j);
        if(position != arc_costs[i].end())
            position->second += delta;
    }

    void multiplyArcCost(int i, int j, float factor) override {
        auto position = arc_costs[i].find(j);
        if(position != arc_costs[i].end())
            position->second *= factor;
    }

    int getArcCost(int i, int j) override {
        auto position = arc_costs[i].find(j);
        return position != arc_costs[i].end()? position->second : 0;
    }

    /** Scaling **/
    void scaleData(float scaling) override{
        for(int i = 0; i < n_nodes; i++) {
            multiplyNodeCost(i, scaling);
            for(auto & it : arc_costs[i])
                it.second *= scaling;
        }
    }

private:
    std::vector<std::map<int, int>> arc_costs;

};

struct ResourceDataMatrix: ResourceData {

    /** Resource data management **/
    //Constructors and Destructors
    explicit ResourceDataMatrix(int n_nodes): ResourceData(n_nodes) {
        arc_costs.resize(n_nodes, std::vector<int>(n_nodes, 0));
    }
    ~ResourceDataMatrix() = default;

    void reset() override {ResourceData::reset(); arc_costs.clear();}

    /** Arc Data **/
    void setArcCost(int i, int j, int cost) override {arc_costs[i][j] = cost;}
    int getArcCost(int i, int j) override {return arc_costs[i][j];}
    void increaseArcCost(int i, int j, int delta) override {arc_costs[i][j] += delta;}
    void multiplyArcCost(int i, int j, float factor) override {arc_costs[i][j] *= factor;}

    /** Scaling **/
    void scaleData(float scaling) override{
        for(int i = 0; i < n_nodes; i++){
            multiplyNodeCost(i, scaling);
            for(int j = 0; j < n_nodes; j++)
                multiplyArcCost(i, j, scaling);
        }
    }

private:
    std::vector<std::vector<int>> arc_costs;
};

#endif
