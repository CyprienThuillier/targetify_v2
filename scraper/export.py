import csv
import os

def export_file(targets: list, filename: str = "export.csv", append: bool = False):
    targets = [t for t in targets if t is not None]
    if not targets:
        return
    os.makedirs(os.path.dirname(filename) if os.path.dirname(filename) else ".", exist_ok=True)
    mode = "a" if append else "w"
    file_exists = append and os.path.exists(filename)
    with open(filename, mode, newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(targets[0].keys()))
        if not file_exists:
            writer.writeheader()
        writer.writerows(targets)
