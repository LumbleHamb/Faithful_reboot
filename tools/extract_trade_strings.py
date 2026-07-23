import os
import subprocess

app_path = r"C:\Users\Vance Company\Documents\Personal\Project\TradeNations.app"

executables = []

for root, dirs, files in os.walk(app_path):
    for file in files:
        full_path = os.path.join(root, file)

        # iOS executable usually has no extension
        if "." not in file and os.path.isfile(full_path):
            executables.append(full_path)

if not executables:
    print("No executable found.")
    exit()

print("Possible executables found:")
for i, exe in enumerate(executables):
    print(f"{i}: {exe}")

choice = int(input("Select executable number: "))

binary = executables[choice]

print("\nExtracting strings from:")
print(binary)

# Simple Python strings extractor (no extra programs needed)
with open(binary, "rb") as f:
    data = f.read()

strings = []
current = ""

for byte in data:
    if 32 <= byte <= 126:
        current += chr(byte)
    else:
        if len(current) >= 4:
            strings.append(current)
        current = ""

output = "\n".join(strings)

output_file = os.path.join(
    os.path.dirname(app_path),
    "TradeNations_strings.txt"
)

with open(output_file, "w", encoding="utf-8") as f:
    f.write(output)

print("\nDone!")
print("Saved:")
print(output_file)