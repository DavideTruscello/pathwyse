import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..')))
from bin.wrapper import PWSolver

#Read instance name from console
instance = sys.argv[1]

#Create a PathWyse solver
pathwyse = PWSolver()

#Read problem
pathwyse.readProblem(instance)

#Setup algorithms
pathwyse.setupAlgorithms()

#Solve the problem
pathwyse.solve()

#Print best solution
pathwyse.printBestSolution()