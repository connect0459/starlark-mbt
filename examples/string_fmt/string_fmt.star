words = ["starlark", "moonbit", "interpreter"]

print(", ".join(words))
print(words[0].upper())
print(" hello ".strip())
print("{}+{}={}".format(1, 2, 1 + 2))

csv = "alice,30,engineer"
parts = csv.split(",")

print(parts)
print("name={} age={} role={}".format(*parts))
