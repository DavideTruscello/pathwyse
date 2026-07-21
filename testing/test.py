import csv
import sys
import os
import yaml
import itertools

from bin.wrapper import PWSolver

SETTINGS_TEMPLATE = "../pathwyse.set"   # il file template che mi hai mostrato
SETTINGS_OUT = "./.tmp/pathwyse.set"        # il file generato per ogni run


def parse_settings(path):
    settings = {}
    order = []
    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            key, value = key.strip(), value.strip()
            settings[key] = value
            order.append(key)
    return settings, order


def write_settings(settings, order, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        for key in order:
            f.write(f"{key} = {settings[key]}\n")
        for key in settings:
            if key not in order:
                f.write(f"{key} = {settings[key]}\n")


def update_settings_file(algorithm, time_limit):
    settings, order = parse_settings(SETTINGS_TEMPLATE)

    settings["main_algorithm"] = algorithm["name"]
    settings["algo/default/timelimit"] = str(time_limit)

    for param_key, param_value in algorithm.get("params", {}).items():
        settings[param_key] = str(param_value)

    write_settings(settings, order, SETTINGS_OUT)
    return SETTINGS_OUT


def run_campaign(config_path="config.yaml"):
    with open(config_path) as f:
        test_data = yaml.load(f, Loader=yaml.FullLoader)

    algorithms = test_data["algorithms"]
    time_limits = test_data["time_limits"]
    instance_dirs = test_data["instances"]

    instances = []
    for d in instance_dirs:
        if os.path.isdir(d):
            for fname in sorted(os.listdir(d)):
                instances.append(os.path.join(d, fname))
        else:
            instances.append(d)
    results = []
    for instance, algorithm, tl in itertools.product(instances, algorithms, time_limits):
        settings_path = update_settings_file(algorithm, tl)

        pathwyse = PWSolver(settings_path)
        pathwyse.readProblem(instance)
        pathwyse.setupAlgorithms()
        pathwyse.solve()

        result = {
            "instance": instance,
            "algorithm": algorithm["name"],
            "time_limit": tl,
            "n_solutions": pathwyse.getNumberOfSolutions(),
            "objective": pathwyse.getSolutionObjective(0) if pathwyse.getNumberOfSolutions() > 0 else None,
            "arc_cost": pathwyse.getSolutionArcCost(0) if pathwyse.getNumberOfSolutions() > 0 else None,
            "time": pathwyse.getGlobalTime(),
            **algorithm["params"]
        }
        results.append(result)

        pathwyse.clearSolutions()

    # Append results to file
    keys = results[0].keys()
    with open('results_test.csv', 'w', newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, keys)
        dict_writer.writeheader()
        dict_writer.writerows(results)


if __name__ == "__main__":
    run_campaign()