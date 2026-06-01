load("utils.star", "clamp", "pipeline")

data = [-5, 0, 3, 7, 12]
clamped = [clamp(x, 0, 10) for x in data]
print(clamped)

result = pipeline(
    "  Hello, World!  ",
    lambda s: s.strip(),
    lambda s: s.lower(),
    lambda s: s.replace(",", ""),
)
print(result)
