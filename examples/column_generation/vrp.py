from columngen.master import RMP
from columngen.pricer import SPPRCLIB
import time
import sys

def printIterationInfo(master, pricers, iteration, duals, bestRC, costs, columns, start_time):
    print("Iteration " + str(iteration))
    print("Bound: " + str(master.getObj()))
    end_time = time.time()
    print("Time: " + str(end_time - start_time))

    mode = ("heuristic" if pricers.isEnsembleUsed() else "exact")
    print("Mode: " + mode)

    print("Duals:")
    print(duals)
    print("N sols: " + str(len(costs)))
    print("Best RC: " + str(bestRC))
    print("Costs:")
    print(costs)
    print("Columns:")
    print(columns)
    print("------------------------------------")


#Setup: data_path = instance path, K = number of vehicles
data_path = sys.argv[1]
K = int(sys.argv[2]) 

pricers = SPPRCLIB(data_path)
num_nodes = pricers.getNumNodes()
max_obj = 1500000 #Max objective to initialize dummy variable

master = RMP(K, num_nodes)
master.buildModel(max_obj)

#CG
iteration = 0
threshold = -1E-5
pricers.useEnsemble(True)
termination = False

start = time.time()

def create_pp_instance(duals, original_path, iteration, scaling=100, output_dir="snapshots"):
    import os
    os.makedirs(output_dir, exist_ok=True)

    mu = duals[0]

    with open(original_path) as f:
        lines = f.readlines()

    edges = []
    in_edge = False
    e_start = e_end = None
    for idx, line in enumerate(lines):
        if line.strip() == "EDGE_COST":
            in_edge = True; e_start = idx; continue
        if in_edge:
            if line.strip() == "END":
                e_end = idx; in_edge = False; continue
            p = line.split()
            edges.append((int(p[0]), int(p[1]), float(p[2])))

    new_edges = []
    for (i, j, t_ij) in edges:
        p_ij = t_ij - scaling * mu[j]    # VERIFICA: mu[j] o mu[i]
        new_edges.append(f"{i} {j} {int(round(p_ij))}\n")

    out = lines[:e_start+1] + new_edges + lines[e_end:]
    path = os.path.join(output_dir, f"snapshot_iter_{iteration}.txt")
    with open(path, "w") as f:
        f.writelines(out)
    return path

print("Optimizing...\n")
while(not termination):
    #RMP solve and obtain new duals
    master.solve()
    duals = master.getDuals()
    iteration += 1


    #Update pricers and solve them
    pricers.updatePricers(duals) 
    pricers.solve() 

    #Collect columns and update RMP
    bestRC, costs, columns = pricers.collectColumns()
    if iteration % 50 == 0:
        printIterationInfo(master, pricers, iteration, duals, bestRC, costs, columns, start)
        create_pp_instance(duals, data_path, iteration)
    if bestRC < threshold:
        for i in range(len(columns)):
            master.addColumn(costs[i], columns[i])
        if not pricers.isEnsembleUsed():
            pricers.useEnsemble(True)
    elif pricers.isEnsembleUsed():
        pricers.useEnsemble(False)
    else:
        termination = True
    pricers.clearColumns()
end = time.time()

print("Optimization complete.")
print("Objective: " + str(master.getObj()))
print("Iterations: " + str(iteration))
print("Time: " + str(end - start))
#master.writeModel()

